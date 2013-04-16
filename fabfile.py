import time
from fabric.api import run, execute, env

env.use_ssh_config = True

branch = "master"
repo = "git://github.com/sunlightlabs/scout.git"

# default to staging, override with "fab [command] --set target=production"
env.target = env.target or "staging"

if target == "staging":
  env.hosts = ["alarms@dupont"]
  username = "alarms"
elif target == "production":
  env.hosts = ["scout@scout"]
  username = "scout"


home = "/projects/%s" % username
shared_path = "%s/shared" % home
version_path = "%s/versions/%s" % (home, time.strftime("%Y%m%d%H%M%S"))
current_path = "%s/current" % home


## can be run only as part of deploy

def checkout():
  run('git clone -q -b %s %s %s' % (branch, repo, version_path))

def links():
  run("ln -s %s/config.yml %s/config/config.yml" % (shared_path, version_path))
  run("ln -s %s/mongoid.yml %s/config/mongoid.yml" % (shared_path, version_path))
  run("ln -s %s/services.yml %s/config/services.yml" % (shared_path, version_path))
  run("ln -s %s/config.ru %s/config.ru" % (shared_path, version_path))
  run("ln -s %s/unicorn.rb %s/unicorn.rb" % (shared_path, version_path))

def dependencies():
  # run("rvm rvmrc trust %s" % version_path)
  run("cd %s && bundle install --local" % version_path)

def create_indexes():
  run("cd %s && rake create_indexes" % version_path)

def make_current():
  run('rm -f %s && ln -s %s %s' % (current_path, version_path, current_path))

# TODO...
def prune_releases():
  pass


## can be run on their own

def set_crontab():
  run("cd %s && rake crontab:set environment=%s current_path=%s" % (current_path, environment, current_path))

def disable_crontab():
  run("cd %s && rake crontab:disable" % current_path)

def start():
  run("cd %s && unicorn -D -l %s/%s.sock -c unicorn.rb" % (username, current_path, shared_path))

def stop():
  run("kill `cat %s/unicorn.pid`" % shared_path)

def restart():
  run("kill -HUP `cat %s/unicorn.pid`" % shared_path)

def clear_cache():
  run("cd %s && rake clear_cache" % current_path)
  

def deploy():
  execute(checkout)
  execute(links)
  execute(dependencies)
  execute(create_indexes)
  execute(make_current)
  execute(set_crontab)
  execute(restart)
