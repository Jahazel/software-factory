import json
import sys
from pathlib import Path

event = json.load(sys.stdin)
if event.get('hook_event_name') == 'SessionStart' and event.get('source') in {'startup', 'resume', 'clear', 'compact'}:
    context = Path(__file__).with_name('startup-context.md').read_text()
    print(json.dumps({'hookSpecificOutput': {'hookEventName': 'SessionStart', 'additionalContext': context}}))
