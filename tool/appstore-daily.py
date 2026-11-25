"""Sancta Via daily digest:
- App Store downloads per app (App Store Installation / Detailed dataset;
  Apple generates instances daily, first data ~24-48h after 2026-11-25 release)
- Store indexing status per app (US)
- F-Droid MR CI status
Optionally posts to Telegram when TG_BOT_TOKEN + TG_CHAT_ID are set.
"""
import json, os, subprocess, time, datetime

ENV = {'PATH': '/opt/homebrew/opt/ruby/bin:/opt/homebrew/bin:/usr/bin:/bin',
       'GEM_PATH': '/Users/jason/.local/share/fastlane/4.0.0:/opt/homebrew/Cellar/fastlane/2.241.2/libexec',
       'HOME': os.path.expanduser('~')}

def jwt():
    return subprocess.run(['/opt/homebrew/opt/ruby/bin/ruby', '-rspaceship', '-e', r'''
require "spaceship"
t = Spaceship::ConnectAPI::Token.create(key_id: "W5R7BJN9W4", issuer_id: "2837ffd2-216c-4f13-b77b-1f467f6f9cce", filepath: "/Users/jason/.fastlane/AuthKey_W5R7BJN9W4.p8")
print t.text
'''], capture_output=True, text=True, env=ENV).stdout.strip()

def curl_json(url, token, tries=3):
    for i in range(tries):
        r = subprocess.run(['curl', '-s', '-H', 'Authorization: Bearer ' + token, url],
                           capture_output=True, text=True)
        try:
            return json.loads(r.stdout)
        except Exception:
            time.sleep(5)
    return None

NAMES = {
 '6837912280': 'Bible', '6837912502': 'Examen', '6837912688': 'Devotions',
 '6837912721': 'Calendar', '6837912870': 'Novena', '6837914555': 'Prayer',
 '6837916017': 'Saints',
}
MR_IDS = ['58973', '58974', '58975', '58976', '58977', '58978', '58979']
BUNDLES = {
 'Bible': 'bible-reading-app', 'Examen': 'confession-companion', 'Devotions': 'devotionals',
 'Calendar': 'liturgical-calendar-app', 'Novena': 'novena-companion',
 'Prayer': 'prayer-companion', 'Saints': 'saint-companion',
}

def digest():
    token = jwt()
    lines = ['Sancta Via daily digest — ' + datetime.datetime.now().strftime('%a %d %b %Y %H:%M')]

    # downloads
    ids = json.load(open('/tmp/app_report_ids.json'))
    lines.append('')
    lines.append('INSTALLS (App Store):')
    any_data = False
    for appid, name in NAMES.items():
        rid = ids.get(appid)
        if not rid:
            lines.append(f'  {name}: (no report mapped)')
            continue
        inst = curl_json('https://api.appstoreconnect.apple.com/v1/analyticsReports/'
                         + rid + '/instances', token, tries=2)
        if not inst or not inst.get('data'):
            lines.append(f'  {name}: no daily dataset yet (Apple generates first within ~24-48h of release)')
            continue
        for instance in inst['data'][:2]:
            iid = instance['id']
            seg = curl_json('https://api.appstoreconnect.apple.com/v1/analyticsReports/'
                            + rid + '/instances/' + iid + '/segments', token, tries=2)
            totals = []
            for s in (seg or {}).get('data', []):
                for t in s.get('attributes', {}).get('totalContent', []):
                    label = t.get('label', {}).get('dimensionKeys', {})
                    date = label.get('downloadDate', '?')
                    vals = t.get('values', {})
                    if isinstance(vals, dict):
                        dl = vals.get('downloads', vals.get('value', '?'))
                    else:
                        dl = vals
                    totals.append(f'{date}: {dl}')
            if totals:
                any_data = True
                lines.append(f'  {name}: ' + ' | '.join(totals))
    if not any_data:
        pass

    # indexing status
    lines.append('')
    lines.append('STORE INDEXING (US):')
    for name, bundle in BUNDLES.items():
        d = curl_json('https://itunes.apple.com/lookup?bundleId=net.superversive.sancta-via.'
                      + bundle + '&country=us', token, tries=1) or {}
        if isinstance(d, dict) and d.get('resultCount'):
            lines.append(f'  {name}: INDEXED')
        else:
            lines.append(f'  {name}: not indexed yet')

    # fdroid
    lines.append('')
    lines.append('F-DROID MRs:')
    env = dict(os.environ)
    for mid in MR_IDS:
        r = subprocess.run(['glab', 'api',
            'projects/fdroid%2Ffdroiddata/merge_requests/' + mid], capture_output=True,
            text=True, cwd='/Users/jason/Repos/fdroiddata', env=env)
        try:
            d = json.loads(r.stdout)
            hp = (d.get('head_pipeline') or {}).get('status', 'no-pipeline')
            lines.append(f'  !{mid}: {d.get("state", "?")} / pipeline {hp}')
        except Exception:
            lines.append(f'  !{mid}: (api hiccup)')

    return '\n'.join(lines)

if __name__ == '__main__':
    text = digest()
    print(text)
    tg_token = os.environ.get('TG_BOT_TOKEN', '')
    tg_chat = os.environ.get('TG_CHAT_ID', '')
    if tg_token and tg_chat:
        subprocess.run(['curl', '-s', '-X', 'POST',
            f'https://api.telegram.org/bot{tg_token}/sendMessage',
            '--data-urlencode', f'chat_id={tg_chat}',
            '--data-urlencode', f'text={text}'], capture_output=True)
