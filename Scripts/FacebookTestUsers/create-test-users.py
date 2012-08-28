#!/usr/bin/env python

"""
A simple script to create test users for a Facebook app.
Clears existing test users first.
Update app-info.json with your app id and secret.
See https://developers.facebook.com/apps
Make sure the app is set as a Web app, not Native else this won't work.
"""

__AUTHOR__ = 'Brian Hammond <brian@fictorial.com>'
__COPYRIGHT__ = 'Copyright (C) 2012 Fictorial LLC. All Rights Reserved.'
__LICENSE__ = 'MIT'


import requests
import urlparse
import json
from pprint import pprint
from namegen import MName

user_count = 10

filename = 'app-info.json'
app_info = json.load(file(filename))

access_token = None
try:
    access_token = app_info['access_token']
except KeyError, e:
    print '* OBTAINING AN ACCESS TOKEN'
    r = requests.get('https://graph.facebook.com/oauth/access_token',
                     params=dict(client_id=app_info['id'],
                                 client_secret=app_info['secret'],
                                 grant_type='client_credentials'))
    access_token = urlparse.parse_qs(r.text)['access_token'][0]
    app_info['access_token'] = access_token
    file(filename, 'w').write(json.dumps(app_info))
    print '* SAVED ACCESS TOKEN.'

print '* APP INFO:'
r = requests.get('https://graph.facebook.com/%s' % app_info['id'],
                 params=dict(access_token=access_token))
pprint(r.json)

print '* CLEARING EXISTING USERS... TAKES A WHILE'
r = requests.get('https://graph.facebook.com/%s/accounts/test-users' % app_info['id'],
                 params=dict(access_token=access_token))
existing_users = r.json['data']
for user in existing_users:
    r = requests.get('https://graph.facebook.com/%s' % user['id'],
                     params=dict(access_token=access_token, method='delete'))
    if r.status_code != 200:
        print r.headers

print '* CREATING TEST USERS... TAKES A WHILE'
users = []
for i in range(user_count):
    fullname = '%s %s' % (MName().New(), MName().New())
    r = requests.get('https://graph.facebook.com/%s/accounts/test-users' % app_info['id'],
                     params=dict(access_token=access_token,
                                 method='post',
                                 permissions='read_stream',
                                 name=fullname,
                                 installed='true',
                                 locale='en_US'))
    if r.status_code != 200:
        print r.headers
    else:
        user = r.json
        users.append(user)
        print user['email'], user['password']

first_user = users.pop(0)
print '* LOGIN TO FACEBOOK AS USER %s PASSWORD %s' % (first_user['email'], first_user['password'])

print '* ADDING OTHER USERS AS FRIENDS OF %s...' % first_user['email']
for target_user in users:
    # make friend request
    url = 'https://graph.facebook.com/%s/friends/%s' % (first_user['id'], target_user['id'])
    r = requests.get(url, params=dict(access_token=first_user['access_token'], method='post'))
    if r.status_code != 200:
        print r.headers
    else:
        # respond to friend request
        url = 'https://graph.facebook.com/%s/friends/%s' % (target_user['id'], first_user['id'])
        r = requests.get(url, params=dict(access_token=target_user['access_token'], method='post'))
        if r.status_code != 200:
            print r.headers

print '* ALL DONE! ENJOY!'
