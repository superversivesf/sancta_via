"""Maps app id -> 'App Store Installation and Deletion Detailed' report id.

Uses curl for transport (the Apple API edge resets some python-urllib connections
when called repeatedly in quick succession; curl is stable).
"""
import json, os, subprocess, time

JWT_SCRIPT = r'''
require "spaceship"
t = Spaceship::ConnectAPI::Token.create(key_id: "W5R7BJN9W4", issuer_id: "2837ffd2-216c-4f13-b77b-1f467f6f9cce", filepath: "/Users/jason/.fastlane/AuthKey_W5R7BJN9W4.p8")
print t.text
'''

ENV = {'PATH': '/opt/homebrew/opt/ruby/bin:/opt/homebrew/bin:/usr/bin:/bin',
       'GEM_PATH': '/Users/jason/.local/share/fastlane/4.0.0:/opt/homebrew/Cellar/fastlane/2.241.2/libexec',
       'HOME': os.path.expanduser('~')}

def jwt():
    return subprocess.run(['/opt/homebrew/opt/ruby/bin/ruby', '-rspaceship', '-e', JWT_SCRIPT],
                          capture_output=True, text=True, env=ENV).stdout.strip()

def curl_json(url, token, tries=3):
    for i in range(tries):
        r = subprocess.run(['curl', '-s', '-H', 'Authorization: Bearer ' + token, url],
                           capture_output=True, text=True)
        try:
            return json.loads(r.stdout)
        except Exception:
            time.sleep(5)
    return None

REQ_IDS = {
 '6837912280': '0c3901e3-747c-4534-af53-4687e9acea73',
 '6837912502': 'fb9d3459-f4f6-4570-8764-bfb42edddfbe',
 '6837912688': 'e6187b9f-1d02-444f-a2f8-3b363b4a1cde',
 '6837912721': '5e3bdacc-c824-4b08-9478-e31944902027',
 '6837912870': '63bdb99d-d3cd-49bd-b505-97ffe313f52e',
 '6837914555': '1fd7eb94-e6b6-434b-aec2-406903b93fab',
 '6837916017': 'bc598901-0b80-4db4-8889-64e6527701f2',
}

def main():
    out = {}
    token = jwt()
    for appid, req_id in REQ_IDS.items():
        d = curl_json('https://api.appstoreconnect.apple.com/v1/analyticsReportRequests/'
                      + req_id + '/reports', token, tries=2)
        got = None
        for rep in (d or {}).get('data', []):
            if rep['attributes']['name'] == 'App Store Installation and Deletion Detailed':
                got = rep['id']; break
        out[appid] = got
        time.sleep(2)
    json.dump(out, open('/tmp/app_report_ids.json', 'w'), indent=1)
    for k, v in out.items():
        print(k, '->', v or 'MISSING')

if __name__ == '__main__':
    main()
