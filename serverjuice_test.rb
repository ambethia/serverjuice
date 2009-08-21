require 'test/unit'
require 'rubygems'
require 'shoulda'

require 'serverjuice'

class ServerJuiceTest < Test::Unit::TestCase
  context "Generated script" do
    setup do
      script = ServerJuice.new('test_juicer', 'example.com', 'tasty', "mysql_password").generate

      @sections = script.split(/\n\n/)
      @sections.last.chomp!
    end

    should "inject script name in header" do
      assert_equal '# test_juicer.sh:', @sections[0].split(/\n/)[0]
    end

    should "inject hostname in setup variables" do
      assert_equal 'DESIRED_HOSTNAME="tasty"', @sections[1].split(/\n/).grep(/DESIRED_HOSTNAME/).first
    end

    should "use temp file when configuring /etc/hosts" do
      assert_equal <<EOS.chomp, @sections[2]
# Set hostname
echo "$DESIRED_HOSTNAME" >/etc/hostname
sed -re "s/^(127.0.1.1[[:space:]]+).*/\\1$DESIRED_HOSTNAME/" </etc/hosts >"test_juicer.tmp" && cp -f "test_juicer.tmp" /etc/hosts && rm -f "test_juicer.tmp"
/etc/init.d/hostname.sh start
EOS
    end

    should "set the mysql root password" do
      assert_equal <<EOS.chomp, @sections[7]
# Set MySQL root password
mysqladmin -u root password "mysql_password"
EOS
    end

    should "use temp file when configuring passenger" do
      assert_equal <<EOS.chomp, @sections[16]
# Install and setup Passenger
gem install passenger
(echo; echo) | passenger-install-apache2-module | tee "test_juicer.tmp"
cat "test_juicer.tmp" | grep -A10 "The Apache 2 module was successfully installed" | egrep "(LoadModule|Passenger(Root|Ruby))" | sed -r $'s:\\e\\\\[[0-9]+m::g' >/etc/apache2/conf.d/passenger
rm "test_juicer.tmp"
apache2ctl graceful
EOS
    end
  end
end 
