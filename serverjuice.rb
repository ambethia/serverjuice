class ServerJuice
  attr_reader :script_name, :server, :hostname

  def initialize(script_name, server, hostname, mysql_password = "")
    @script_name = script_name
    @server = server
    @hostname = hostname
    @mysql_password = mysql_password
  end

  def remote_tmp_file
    "#{script_name}.tmp"
  end

  def remote_script_name
    "#{script_name}.sh"
  end

  # Create a script on the remote server that will configure it, and run it
  def deploy
    system %Q[ssh -lroot "#{server}" <<'EOF'
 	cat >"#{remote_script_name}" <<'EOS'
#{generate}EOS
chmod +x "#{remote_script_name}"
source "#{remote_script_name}"
EOF
    ]
  end

  def generate
    <<-EOF
# #{remote_script_name}:
#
# Set up a clean Ubuntu install for Rails production deployment.
#
# Tested on:
#
# linode.com - Ubuntu 9.04
#
# More info:
#
# http://github.com/hartcode/serverjuice
#

# Ensure hostname is configured
DESIRED_HOSTNAME="#{hostname}"
if [ -z "$DESIRED_HOSTNAME" ]; then
	echo DESIRED_HOSTNAME must be set.
	exit 1
fi

# Set hostname
echo "$DESIRED_HOSTNAME" >/etc/hostname
sed -re "s/^(127.0.1.1[[:space:]]+).*/\\1$DESIRED_HOSTNAME/" </etc/hosts >"#{remote_tmp_file}" && cp -f "#{remote_tmp_file}" /etc/hosts && rm -f "#{remote_tmp_file}"
/etc/init.d/hostname.sh start

# Upgrade system packages
apt-get -y update
apt-get -y upgrade

# Install essential tools
apt-get -y install build-essential wget

# Install Apache 2
apt-get -y install apache2 apache2-prefork-dev

# Install MySQL Server
apt-get -y install mysql-server mysql-client libmysqlclient15-dev

# Set MySQL root password
mysqladmin -u root password "#{@mysql_password}"

# Install Git
apt-get -y install git-core

# Install libreadline-dev for compiling ruby
apt-get -y install libreadline-dev

# Install more secure version of ruby
(
RUBY=ruby-1.8.7-p174
cd /usr/local/src &&
rm -rf $RUBY $RUBY.tar.gz &&
wget ftp://ftp.ruby-lang.org/pub/ruby/1.8/$RUBY.tar.gz &&
tar -xzf $RUBY.tar.gz &&
cd $RUBY &&
./configure &&
make &&
make install &&
cd ..
)

# Prevent ri and rdoc from being installed unless commented out
RI="--no-ri"
RDOC="--no-rdoc"

# Install RubyGems
(
RUBYGEMS=rubygems-1.3.5
cd /usr/local/src &&
rm -rf $RUBYGEMS $RUBYGEMS.tgz &&
# Note: Filename in URL does not determine which file to download
wget http://rubyforge.org/frs/download.php/60718/rubygems-1.3.5.tgz &&
tar -xzf $RUBYGEMS.tgz &&
cd $RUBYGEMS &&
ruby setup.rb $RDOC $RI &&
cd ..
)

# Put a default .gemrc in place
cat >> ~/.gemrc <<EOS
--- 
:backtrace: false
:benchmark: false
:bulk_threshold: 1000
:sources: 
- http://gems.rubyforge.org
- http://gems.github.com
:update_sources: true
:verbose: true
gem: $RDOC $RI
EOS

# Install Rails
gem install rails

# Install MySQL Ruby driver
gem install mysql

# Install and setup Passenger
gem install passenger
(echo; echo) | passenger-install-apache2-module | tee "#{remote_tmp_file}"
cat "#{remote_tmp_file}" | grep -A10 "The Apache 2 module was successfully installed" | egrep "(LoadModule|Passenger(Root|Ruby))" | sed -r $'s:\\e\\\\[[0-9]+m::g' >/etc/apache2/conf.d/passenger
rm "#{remote_tmp_file}"
apache2ctl graceful

# Final success message
cat <<'EOS'



Congratulations!

ServerJuice has finished juicing up your server with Rails, MySQL and Passenger!


Suggested further steps:

1. Depending on your needs, you may want to create a user for deployment.

   Below I'll use "user@#{hostname}.yourhost.com" to talk about the account
   you'll be using for deployment, whether it be root or another user.

2. Create ssh keys for the deployment user on your server:

   #{hostname}:$ ssh-keygen -t rsa -f ~/.ssh/id_rsa

3. Add the created public key to github to make deploying from github work.

   #{hostname}:$ cat ~/.ssh/id_rsa.pub # then copy'n'paste to github deploy key

4. Create ssh keys on your development machine and add to your server:

   $ ssh-keygen -t rsa -f ~/.ssh/id_rsa
   $ ssh user@#{hostname}.yourhost.com "cat >>~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" <~/.ssh/id_rsa.pub

5. Capify your app and set it up to deploy to your new server.

   If deploying from github, remember to put "default_run_options[:pty] = true"
   in your deploy recipe to avoid host key verification errors.

6. Once you've deployed, configure Apache to be aware of your Passenger app:

   <VirtualHost *:80>
      ServerName #{hostname}.yourhost.com
      DocumentRoot /var/www/your-app/current/public
   </VirtualHost

   Be sure to point to "public" in your Rails app!

   To restart your Passenger app, touch tmp/restart.txt in the app's directory.


Links to more information:

Passenger User's Guide With Apache:
    http://www.modrails.com/documentation/Users%20guide%20Apache.html

GitHub - Deploying with Capistrano:
    http://github.com/guides/deploying-with-capistrano


Good luck and remember to have fun!
EOS
    EOF
  end
end
