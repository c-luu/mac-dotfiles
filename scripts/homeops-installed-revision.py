"""Print the actual Git revision of HomeOps in the invoking uv tool environment."""

import json
import re
import sys
from importlib import metadata


def installed_revision():
    source = json.loads(metadata.distribution('homeops').read_text('direct_url.json'))
    if source.get('url', '').rstrip('/').removesuffix('.git') != 'https://github.com/c-luu/homeops':
        raise ValueError('unexpected package source')
    vcs = source.get('vcs_info', {})
    commit = vcs.get('commit_id', '')
    if vcs.get('vcs') != 'git' or not re.fullmatch('[0-9a-f]{40}', commit):
        raise ValueError('unverifiable Git revision')
    return commit


if __name__ == '__main__':
    try:
        print(installed_revision())
    except (metadata.PackageNotFoundError, TypeError, ValueError, AttributeError, OSError):
        sys.exit(1)
