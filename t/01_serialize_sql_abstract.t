use Test::More tests => 4;
use lib ('./blib/lib', '../blib/lib');

use CGI::Session::Serialize::SQLAbstract;

 is(CGI::Session::Serialize::SQLAbstract::_time_to_iso8601('bad'), undef, 'time_to_iso8601 testing bad data');

 is(CGI::Session::Serialize::SQLAbstract::_time_to_iso8601('1059085070'), 
    _compute_local_time_from_indiana_time(2003,07,24,17,17,50)
, 'time_to_iso8601 testing good data');

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
	  'creation_time' => _compute_local_time_from_indiana_time(1973,05,10,14,01,47),
	  'order_id'      => '27',		
	  'order_id_exp_secs' => '127'
    },
, 'freeze() basic unit test');


my $thawed = CGI::Session::Serialize::SQLAbstract::thaw(undef,{
				session_id => 'xxxx',
				creation_time    => '105908507',
				last_access_time => '105908507',
				end_time	     => '105908507',
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


# Why did I bother with this hoop jump? 
# It makes my tests past in other time zones, but I'm sure there as a simpler way
sub  _compute_local_time_from_indiana_time {
    my ($year,$month,$day, $hour,$min,$sec) = @_;

    # Conveniently, we don't go on Daylight Savings Time here.
    my $gmt_minus_indiana_time = 5;

    use Date::Calc (qw/Now Add_Delta_DHMS/);

   my $local_hour = (Now(0))[0];
   my $gmt_hour = (Now(1))[0];

    my $gmt_minus_localtime = $gmt_hour - $local_hour;

    my $diff_from_indiana = $gmt_minus_indiana_time - $gmt_minus_localtime;

    my ($loc_year,$loc_month,$loc_day, $loc_hour,$loc_min,$loc_sec) = 
        Add_Delta_DHMS($year,$month,$day, $hour,$min,$sec, undef,$diff_from_indiana,undef,undef);
    
	  # format is '1973-05-10 14:01:47',
    return sprintf("%.4d-%.2d-%.2d %.2d:%.2d:%.2d",$loc_year,$loc_month,$loc_day,$loc_hour,$loc_min,$loc_sec);
}
