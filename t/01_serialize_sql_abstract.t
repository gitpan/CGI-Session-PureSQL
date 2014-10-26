use Data::Dumper;
use Test::More tests => 4;
use lib ('./blib/lib', '../blib/lib');

use CGI::Session::Serialize::SQLAbstract;

 is(CGI::Session::Serialize::SQLAbstract::_time_to_iso8601('bad'), undef, 'time_to_iso8601 testing bad data');
 is(CGI::Session::Serialize::SQLAbstract::_time_to_iso8601('1059085070'), '2003-07-24 22:17:50', 'time_to_iso8601 testing good data');

 my $frozen = CGI::Session::Serialize::SQLAbstract::freeze(undef,{
		 _SESSION_ID 	=> 'xxxx',
		 _SESSION_CTIME => '105908507',
		 _SESSION_REMOTE_ADDR => '127.0.0.1',
		 order_id => 27,
		 _SESSION_EXPIRE_LIST => {
				 order_id => '127',

		 },
	 });

is_deeply($frozen,
	{
	  'remote_addr' => '127.0.0.1',
	  'last_access_time' => undef,
	  'duration' => undef,
	  'session_id' => 'xxxx',
	  'creation_time' => '1973-05-10 19:01:47',
	  'order_id'      => '27',		
	  'order_id_exp_secs' => '127'
    },
, 'freeze() basic unit test');


my $thawed = CGI::Session::Serialize::SQLAbstract::thaw(undef,{
				session_id => 'xxxx',
				creation_time    => '105908507',
				last_access_time => '105908507',
				duration	     => '105908507',
				remote_addr	 	 => '127.0.0.1',
				order_id	=> '27',
				order_id_exp_secs => 127,
			});

is_deeply(
		$thawed,
		{
			_SESSION_ID 	=> 'xxxx',
			_SESSION_CTIME => '105908507',
			_SESSION_ATIME => '105908507',
			_SESSION_ETIME => '105908507',
			_SESSION_REMOTE_ADDR => '127.0.0.1',
			order_id => '27',
			_SESSION_EXPIRE_LIST => {
				order_id => '127',

			},
		},
	' thaw() basic unit test');


