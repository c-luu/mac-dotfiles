#!/usr/bin/env python3
"""Exercise terminal prompts with isolated HOME and tools; never contact real hosts."""
import errno
import json
import os
from pathlib import Path
import pty
import select
import shutil
import signal
import subprocess
import tempfile
import time

REPO = Path(__file__).resolve().parent.parent
MOCK = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
args = sys.argv[1:]
if os.environ.get('FAIL_TOOL') == name: sys.exit(1)
home = Path(os.environ['HOME'])
with open(os.environ['TOOL_LOG'], 'a') as f:
    f.write(json.dumps([name, args])+'\n')
if name == 'chezmoi':
    if 'execute-template' in args:
        for i in range(int(os.environ.get('PROFILE_COUNT','3'))):
            ident = 'profile-'+str(i)
            print('\t'.join(['P',ident,'Example Author','author@example.com','alias-'+str(i),'git.example.com','22','git',str(home/'.ssh'/ident),'example-account-'+str(i)]))
            print('\t'.join(['R',ident,str(home/'Projects'/ident)]))
    elif 'apply' in args:
        (home/'.ssh').mkdir(exist_ok=True)
elif name == 'vim':
    target = Path(args[0])
    target.parent.mkdir(parents=True,exist_ok=True)
    if not target.exists(): target.write_text('fixture entrypoint\n')
elif name == 'validate':
    if os.environ.get('FAIL_PREFLIGHT') and '--preflight' in args: sys.exit(1)
elif name == 'keygen':
    mode = os.environ.get('KEY_MODE','encrypted')
    key = Path(args[args.index('-f')+1])
    if '-t' in args:
        if mode == 'failed': sys.exit(1)
        if mode == 'interrupted': os.kill(os.getppid(), 2); sys.exit(130)
        key.write_text('PRIVATE FIXTURE DO NOT PRINT\n')
        Path(str(key)+'.pub').write_text('PUBLIC FIXTURE\n')
        key.chmod(0o600)
    elif '-y' in args: sys.exit(0 if mode == 'empty' else 1)
    elif '-l' in args: sys.exit(0)
elif name == 'pbcopy':
    data = sys.stdin.read()
    if data != 'PUBLIC FIXTURE\n': sys.exit(98)
    with open(os.environ['CLIPBOARD_LOG'],'a') as f: f.write(data)
elif name == 'ssh':
    # Deliberately drain stdin: the runner must connect this child to the terminal,
    # never the remaining profile records. Do not read terminal input in the mock.
    if not os.isatty(0): sys.stdin.read()
    print('Hi expected-account! authenticated')
    sys.exit(1)
'''

def run_case(answers=None, *, profiles=3, key_mode='encrypted', existing=False,
             occupied=None, fail_preflight=False, signal_prompt=None, preconfigured=True,
             close_prompt=None, fail_tool=None, missing_chezmoi=False):
    with tempfile.TemporaryDirectory(prefix='guided setup fixture ') as tmp:
        f = Path(tmp)
        home = f/'home with spaces'
        home.mkdir()
        (home/'.ssh').mkdir()
        # Preserve unrelated settings on reruns and manual integration.
        (home/'.gitconfig').write_text('unrelated git fixture\n')
        (home/'.ssh/config').write_text('unrelated ssh fixture\n')
        if preconfigured:
            (home/'.config/chezmoi').mkdir(parents=True)
            (home/'.config/chezmoi/chezmoi.toml').write_text('existing profile fixture\n')
        if existing or occupied:
            for i in range(profiles):
                key = home/'.ssh'/('profile-'+str(i))
                if existing:
                    key.write_text('PRIVATE FIXTURE DO NOT PRINT\n')
                    Path(str(key)+'.pub').write_text('PUBLIC FIXTURE\n')
                elif occupied == 'private': key.write_text('occupied\n')
                elif occupied == 'public': Path(str(key)+'.pub').write_text('occupied\n')
                elif occupied == 'symlink': key.symlink_to(home/'missing')
                elif occupied == 'public-symlink': Path(str(key)+'.pub').symlink_to(home/'missing')
        bins = f/'bin'; bins.mkdir()
        for name in ['brew','chezmoi','vim','validate','keygen','ssh','ssh-add','pbcopy']:
            tool=bins/name; tool.write_text(MOCK); tool.chmod(0o755)
        (bins/'validate-tool').write_text(MOCK.replace("name = Path(sys.argv[0]).name", "name = 'validate'"))
        (bins/'validate-tool').chmod(0o755)
        (bins/'validate').write_text('#!/bin/bash\nexec '+chr(34)+str(bins/'validate-tool')+chr(34)+' '+chr(34)+'$@'+chr(34)+'\n')
        env=os.environ.copy()
        env.update(HOME=str(home), PATH=str(bins)+':'+env['PATH'], TOOL_LOG=str(f/'tools'),
                   CLIPBOARD_LOG=str(f/'clipboard'), PROFILE_COUNT=str(profiles), KEY_MODE=key_mode,
                   MAC_DOTFILES_TEST_KEYGEN=str(bins/'keygen'), MAC_DOTFILES_TEST_SSH=str(bins/'ssh'),
                   MAC_DOTFILES_TEST_SSH_ADD=str(bins/'ssh-add'), MAC_DOTFILES_TEST_VALIDATE=str(bins/'validate'),
                   CHEZMOI=str(bins/'chezmoi'))
        if fail_preflight: env['FAIL_PREFLIGHT']='1'
        if fail_tool: env['FAIL_TOOL']=fail_tool
        if missing_chezmoi: env['CHEZMOI']=str(f/'missing-chezmoi')
        # The real batch checker is covered by connectivity.sh. Its mocked chezmoi
        # metadata is intentionally incomplete here, so default to skipping batch.
        pid, fd=pty.fork()
        if pid == 0:
            os.chdir(f)
            os.execve('/bin/bash',['/bin/bash',str(REPO/'scripts/beginner/setup.sh')],env)
        transcript=b''; pending=b''; prompts=[]; deadline=time.monotonic()+15; ended=0
        try:
            while time.monotonic()<deadline:
                ready,_,_=select.select([fd],[],[],0.1)
                if ready:
                    try: data=os.read(fd,65536)
                    except OSError as e:
                        if e.errno==errno.EIO: break
                        raise
                    if not data: break
                    transcript+=data; pending+=data
                    marker=b'[yes/No/stop] '
                    while marker in pending:
                        prefix,pending=pending.split(marker,1)
                        prompt=prefix.decode(errors='replace').split('\r\n')[-1]
                        prompts.append(prompt)
                        if signal_prompt and signal_prompt in prompt:
                            os.write(fd,b'\x03'); continue
                        if close_prompt and close_prompt in prompt:
                            os.write(fd,b'\x04'); continue
                        choice=answers(prompt) if answers else ('no' if 'NETWORK ACTION' in prompt else 'yes')
                        os.write(fd,(choice+'\n').encode())
                ended,status=os.waitpid(pid,os.WNOHANG)
                if ended: break
            else: raise AssertionError('terminal run timed out: '+transcript.decode(errors='replace'))
            if not ended:
                _,status=os.waitpid(pid,0)
        finally:
            os.close(fd)
            try: os.kill(pid,signal.SIGKILL)
            except ProcessLookupError: pass
        out=transcript.decode(errors='replace')
        assert 'PRIVATE FIXTURE' not in out, out
        log=[json.loads(l) for l in (f/'tools').read_text().splitlines()] if (f/'tools').exists() else []
        return os.waitstatus_to_exitcode(status), out, log, prompts


def count(log,name,flag=None):
    return sum(n==name and (flag is None or flag in args) and not (flag=='apply' and '--dry-run' in args) for n,args in log)

code,out,log,prompts=run_case()
assert code==0, out
assert count(log,'keygen','-t')==3 and count(log,'ssh-add')==3 and count(log,'pbcopy')==3
assert count(log,'ssh')==0 and 'connectivity unverified' in out
assert [n for n,a in log].index('brew') < [n for n,a in log].index('vim')
for profiles in [1,4]:
    code,out,log,_=run_case(profiles=profiles)
    assert code==0 and count(log,'keygen','-t')==profiles, out
for occupancy in ['private','public','symlink','public-symlink']:
    code,out,log,_=run_case(occupied=occupancy)
    assert code!=0 and count(log,'keygen','-t')==0, out
for mode in ['empty','failed','interrupted']:
    code,out,log,_=run_case(key_mode=mode)
    assert code!=0 and count(log,'keygen','-t')==1 and count(log,'pbcopy')==0, out
code,out,log,_=run_case(existing=True)
assert code==0 and count(log,'keygen','-t')==0, out
code,out,log,_=run_case(preconfigured=False, profiles=1)
assert code==0, out
for failed_tool in ['brew', 'vim', 'chezmoi']:
    code,out,log,_=run_case(fail_tool=failed_tool)
    assert code!=0 and count(log,'keygen','-t')==0, out
code,out,log,_=run_case(missing_chezmoi=True)
assert code!=0 and count(log,'keygen','-t')==0, out
code,out,log,_=run_case(fail_preflight=True)
assert code!=0 and count(log,'keygen','-t')==0 and count(log,'chezmoi','apply')==0, out
for answer in ['', 'no', 'stop']:
    code,out,log,_=run_case(lambda p: answer if 'LOCAL DEPLOYMENT' in p else 'yes')
    assert code!=0 and count(log,'chezmoi','apply')==0 and count(log,'keygen','-t')==0, out
code,out,log,_=run_case(signal_prompt='LOCAL DEPLOYMENT')
assert code!=0 and count(log,'chezmoi','apply')==0, out
code,out,log,_=run_case(close_prompt='LOCAL DEPLOYMENT')
assert code!=0 and count(log,'chezmoi','apply')==0, out
code,out,log,_=run_case(lambda p: 'no' if ('enroll this key' in p or 'NETWORK ACTION' in p) else 'yes')
assert code==0 and count(log,'ssh-add')==0, out
code,out,log,_=run_case(lambda p: 'no' if 'bounded batch' in p else 'yes')
assert code==0 and count(log,'ssh')==3, out
assert all('StrictHostKeyChecking=ask' in args for name,args in log if name=='ssh')
p=subprocess.run(['/bin/bash',str(REPO/'scripts/beginner/setup.sh')],input='',text=True,capture_output=True)
assert p.returncode==2 and 'no changes made' in p.stderr
print('PASS: terminal setup, consent, cancellation, profiles, credentials, reruns, and network gates (mocked)')
