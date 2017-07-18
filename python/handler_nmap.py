#!/usr/bin/env python
import sys
import subprocess
import os
import glob
import hashlib
import urllib
import urllib2
import json
import re
import time
import shutil
import tempfile
import xml.etree.ElementTree as ET
from xml.dom import minidom

DEVNULL = open(os.devnull, 'wb')

# For verbose output of the scripts execution. Used for debugging
# purposes. obviously...
DEBUG = False

if DEBUG:
    DEVNULL = None


# lazy sanity checks on input
scan_type = sys.argv[1] if sys.argv[1] in ['quick', 'full'] else None
target_host = sys.argv[2] if re.match(
    r'(?!-|\.)[a-zA-Z\d\-\./]{1,63}(?<!-|\.)$', sys.argv[2]) else None
target_project = sys.argv[3] if re.match(
    r'[a-zA-Z\d\-_]+$', sys.argv[3]) else None

# setting up nmap scan profiles
args_quick = ["sudo", "nmap", "-sS", "-sV", "-Pn", "--open", "-v", target_host]
args_full = ["sudo", "nmap", "-sS", "-sV", "-sC",
             "-Pn", "-p0-", "--open", "-v", target_host]
args = list(args_full) if scan_type == "full" else list(args_quick)

# timeout for nmap scan. In seconds. 3600 = 1 hour, 14400 = 4 hours
timeout = 14400

if None in [scan_type, target_host, target_project]:
    print 'Some parameters are missing. Exiting..'
    sys.exit(1)

# Setting up runtime variables based on environment
rocket_chat_url = os.environ['ROCKETCHAT_API_URL']
rosbot_username = os.environ['ROCKETCHAT_BOTUSER']
rosbot_password = os.environ['ROCKETCHAT_PASSWORD']

github_url = os.environ['GITWEB']
gitlab_token = os.environ['GITLAB_TOKEN']
gitlab_server = os.environ['GITSERVER']
gitlab_namespace = os.environ['NAMESPACE']
gitlab_ext_web = os.environ['GITWEB']

# for debug messages. stderr.write pushes output to RC during the script's
# runtime


def debug(string):
    if DEBUG:
        sys.stderr.write('DEBUG: '+string+"\n")

# for consolidating multiple scans


def build_scan_result_map(temp_dir_for_git):
    scopes = {}
    os.chdir(temp_dir_for_git+'/source/scans/nmap/')
    scan_directories = sorted(filter(os.path.isdir, os.listdir(".")))
    for directory in scan_directories:
        nmap_file = glob.glob(directory+'/*.nmap')
        if nmap_file:
            header = open(nmap_file[0], "r").readline()
            if "scan initiated" in header:
                target = header.split(" ")[-1]
                target_key = hashlib.md5(target).hexdigest()
                if target_key in scopes.keys():
                    scopes[target_key] = temp_dir_for_git + \
                        '/source/scans/nmap/'+nmap_file[0]
                else:
                    scopes[target_key] = temp_dir_for_git + \
                        '/source/scans/nmap/'+nmap_file[0]

    return scopes


# for tranlation of room's ID (on which the nmap command was called) into
# plain-text name. if the room starts with 'pen-', then it is used for
# defining the target repo
def get_room_name(roomId):
    login_data = urllib.urlencode(
        {'username': rosbot_username, 'password': rosbot_password})
    req = urllib2.Request(rocket_chat_url+'/api/v1/login', data=login_data)

    try:
        resp = urllib2.urlopen(req)
        info = json.loads(resp.read())
        userId = info['data']['userId']
        userToken = info['data']['authToken']
    except urllib2.HTTPError as error:
        debug('Unknown error occured while authenticating to RC. Wrong creds? NO env variables set?')
        return None

    req = urllib2.Request(rocket_chat_url+'/api/v1/groups.info?roomId='+roomId)
    req.add_header('X-User-Id', userId)
    req.add_header('X-Auth-Token', userToken)
    try:
        resp = urllib2.urlopen(req)
        info = json.loads(resp.read())
        return info['group']['name']
    except urllib2.HTTPError as error:
        if error.code == 400:
            info = json.loads(error.read())
            debug(info['error'])
            return None
        else:
            debug(
                'Unknown error occured while retrieving RC channel name. HTTP error code: '+str(error.code))
            return None

# verfying the existence of optionally supplied project name. Allows to
# launch the nmap scan for a specific project from any channel/room.


def check_for_gitlab_repo(projectName):

    if not projectName.startswith('pen-'):
        projectName = 'pen-'+projectName

    req = urllib2.Request(github_url+'/api/v3/projects/ros%2f'+projectName)
    req.add_header('PRIVATE-TOKEN', gitlab_token)
    try:
        resp = urllib2.urlopen(req)
        info = json.loads(resp.read())
        if info['name'] == projectName:
            return info['name']
        else:
            return None
    except urllib2.HTTPError as error:
        if error.code == 404:
            debug('No pentest projects found in Gitlabs with the provided name.')
            return None
        else:
            debug('Unknown error occured while checking the client repo in gitlab.')
            return None

# tryting to resolve the target project's name via room's name or supplied
# project's name. 'nosave' parameter can be used to bypass the check and
# run a scan without pushing stuff to gitlabs
if target_project != 'nosave':
    roomName = get_room_name(target_project)
    gitRepo = check_for_gitlab_repo(target_project)

    if roomName is not None and roomName.startswith('pen-'):
        target_project = roomName
        debug('Project name derived from room-name.')
    elif gitRepo is not None and gitRepo.startswith('pen-'):
        target_project = gitRepo
        debug(
            'Project name derived from the supplied project name paramter in the command.')
    else:
        target_project = None

if target_project is None:
    print 'Project name missing or unknown. Use project name "nosave" to bypass the requirement or correct the project name.'
    sys.exit(1)


start_time = time.time()
debug(time.strftime("%Y-%m-%d_%H:%M"))

# preparing environment for launching nmap
time_stamped_dir = time.strftime("%Y-%m-%d_%H:%M")
output_temp = "/tmp/rosbot_scans/"+target_project+"/"+time_stamped_dir+"/"
try:
    os.makedirs(output_temp)
except:
    print "Nmap output directory already exists. Someone just recently (within the same minute) launched a scan"
    "for this target. Wait for that scan to finish or at least wait one minute before running the scan again"
    sys.exit()
args.extend(["-oA", output_temp+scan_type])

debug(" ".join(args))
sys.stderr.write("Scan Started.\n")
proc = subprocess.Popen(args, stdout=DEVNULL, stderr=DEVNULL)

# monitoring nmap for timeout
while True:
    proc.poll()
    time.sleep(1)
    return_code = proc.returncode
    now = time.time()
    if (return_code is None) and (now > (start_time + timeout)):
        print 'Timeout reached. Terminating nmap...'
        proc.kill()
        break
    elif return_code is not None:
        break

if not os.path.isfile(output_temp+scan_type+'.xml'):
    print "Nmap failed for: "+target_host+". Nothing to do."
    sys.exit()

# parsing results for quick overview which will be sent back to RC
tree = ET.parse(output_temp+scan_type+'.xml')
root = tree.getroot()
hosts = root.findall('host')

if len(hosts) == 0:
    print "No Live hosts identified. Scan Done for : "+target_host+"."
    shutil.rmtree(output_temp)
    sys.exit()

if target_project == "nosave":
    for host in hosts:
        ip = host.find('address').get('addr')
        ports = host.find('ports').findall('port')
        hostname = 'Hostname missing'
        try:
            hostname = host.find('hostnames').find('hostname').get('name')
        except:
            pass
        print "\nScanning report for: "+ip+" ("+hostname+")\n"
        for port in ports:
            nr = port.get('portid')
            try:
                service = port.find('service')
                svc_name = service.get('name')
                svc_product = service.get('product')
                print nr+"\t"+svc_name+"\t"+svc_product
            except:
                print nr+" - "+" - "
                pass

# cloning, adding, pushing scan results to gitlabs
if target_project != 'nosave':
    temp_dir_for_git = tempfile.mkdtemp()
    debug('git clone git@'+gitlab_server+':'+gitlab_namespace +
          '/'+target_project+'.git '+temp_dir_for_git)
    proc = subprocess.Popen(['git', 'clone', 'git@'+gitlab_server+':'+gitlab_namespace +
                             '/'+target_project+'.git', temp_dir_for_git], stdout=DEVNULL, stderr=DEVNULL)
    proc.wait()

    if not os.path.isdir(temp_dir_for_git+'/source/scans/nmap'):
        debug('Scans directory does not exist in repo. Creating...')
        os.makedirs(temp_dir_for_git+'/source/scans/nmap')

    shutil.copytree(output_temp, temp_dir_for_git +
                    '/source/scans/nmap/'+time_stamped_dir+'_'+scan_type)
    os.chdir(temp_dir_for_git)

    # preparing an XML which can be then used by PenText
    root = ET.Element('section')
    root.attrib['id'] = 'nmap'
    tree = ET.ElementTree(root)
    title = ET.SubElement(root, "title")
    title.text = 'nmap'
    paragraph = ET.SubElement(root, "p")
    paragraph.text = 'We ran nmap with the following commands:'
    scan_items = build_scan_result_map(temp_dir_for_git)
    for item in scan_items:
        target = open(scan_items[item], "r").readline().split(" ")[-1].strip()
        args = list(
            args_full) if "/full" in scan_items[item] else list(args_quick)
        args[-1] = target
        pre = ET.SubElement(root, "pre")
        pre.text = '$ '+' '.join(args)
        paragraph = ET.SubElement(root, "p")
        paragraph.text = 'Outcome:'
        pre = ET.SubElement(root, "pre")
        scan_results = open(scan_items[item], 'rb')
        pre.text = scan_results.read()
        scan_results.close()
    os.chdir(temp_dir_for_git)
    pretty_print = minidom.parseString(ET.tostring(root)).toprettyxml()
    pentext_scans_output_file = open('./source/scans/nmap.xml', 'wb')
    pentext_scans_output_file.write(pretty_print[23:])
    pentext_scans_output_file.close()

    # commiting changes...
    debug("\nPushing results to Gitlab...")
    proc = subprocess.Popen(['git', 'add', 'source/scans'],
                            stdout=DEVNULL, stderr=DEVNULL)
    proc.wait()  # wait until the command finishes
    proc = subprocess.Popen(
        ['git', 'commit', '-m', 'Automatic scan upload'], stdout=DEVNULL, stderr=DEVNULL)
    proc.wait()  # wait until the command finishes
    proc = subprocess.Popen(
        ['git', 'push', '-u', 'origin', 'master'], stdout=DEVNULL, stderr=DEVNULL)
    proc.wait()  # wait until the command finishes

# CLEANUP
shutil.rmtree(output_temp)
if target_project != 'nosave':
    shutil.rmtree(temp_dir_for_git)

print "Scan for "+target_host+" DONE!"
debug('Done @ %s' % (time.time()))
if target_project != "nosave":
    print "Consolidated Nmap results can be found at:"
    print gitlab_ext_web+"/"+gitlab_namespace+"/"+target_project+"/blob/master/source/scans/nmap.xml"
