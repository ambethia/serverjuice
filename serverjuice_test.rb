require 'test/unit'
require 'rubygems'
require 'shoulda'

require 'serverjuice'

class Array
  def chomp_last!
    last.chomp!
    self
  end
end

class ServerJuiceTest < Test::Unit::TestCase
  context "Default generated script" do
    setup do
      @script = ServerJuice.new('test_juicer', 'example.com', 'tasty', "mysql_password").generate

      @generated = @script.split(/\n\n/).chomp_last!

      @expected = <<EOS.split(/\n\n/).chomp_last!
# test_juicer.sh:
#
# Set up a clean Ubuntu 8.04 install for Rails production deployment.
#
# Tested on:
#
# linode.com - Ubuntu 8.04 LTS
#
# More info:
#
# http://github.com/hartcode/serverjuice
#

# Configure your desired options here
DESIRED_HOSTNAME="tasty"
RI="--no-ri"                         # Comment to install ri
RDOC="--no-rdoc"                     # Comment to install RDOC

# Ensure hostname is configured
if [ -z "$DESIRED_HOSTNAME" ]; then
	echo DESIRED_HOSTNAME must be set.
	exit 1
fi

# Set hostname
echo "$DESIRED_HOSTNAME" >/etc/hostname
sed -re "s/^(127.0.1.1[[:space:]]+).*/\\1$DESIRED_HOSTNAME/" </etc/hosts >"test_juicer.tmp" && cp -f "test_juicer.tmp" /etc/hosts && rm -f "test_juicer.tmp"
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

# set a root password
mysqladmin -u root password "mysql_password"

# Install Git
apt-get -y install git-core

# Install more secure version of ruby
(
RUBY=ruby-1.8.6-p383 &&
wget ftp://ftp.ruby-lang.org/pub/ruby/1.8/$RUBY.tar.gz &&
tar xvfz $RUBY.tar.gz &&
cd $RUBY &&
./configure &&
make &&
make install &&
cd .. &&
rm -rf $RUBY $RUBY.tar.gz
)

# Install RubyGems
(
RUBYGEMS=rubygems-1.3.5 &&
cd /usr/local/src &&
rm -rf $RUBYGEMS $RUBYGEMS.tgz &&
# Note: Filename in URL does not determine which file to download
wget http://rubyforge.org/frs/download.php/60718/rubygems-1.3.5.tgz &&
tar -xzf $RUBYGEMS.tgz &&
cd $RUBYGEMS &&
ruby setup.rb $RDOC $RI &&
ln -sf /usr/bin/gem1.8 /usr/bin/gem &&
cd .. &&
rm -rf $RUBYGEMS $RUBYGEMS.tgz
)

# Install Rails
gem install $RDOC $RI rails

# Install MySQL Ruby driver
gem install $RDOC $RI mysql

# Install and setup Passenger
gem install $RDOC $RI passenger
(echo; echo) | passenger-install-apache2-module | tee "test_juicer.tmp"
cat "test_juicer.tmp" | grep -A10 "The Apache 2 module was successfully installed" | egrep "(LoadModule|Passenger(Root|Ruby))" | sed -r $'s:\\e\\\\[[0-9]+m::g' >/etc/apache2/conf.d/passenger
rm "test_juicer.tmp"
apache2ctl graceful
EOS
    end

    should "contain the expected sections" do
      @expected.each_with_index do |section, i|
        assert_equal section, @generated[i]
      end
    end
  end
end 
