use strict;
use lib ('./blib/lib','./blib/arch');

BEGIN { 
	use Test::More;

	if (defined $ENV{DBI_DSN}) {
		require DBI;
		plan tests => 21;
	} else {
		plan skip_all => 'cannot test PureSQL without DB info';
	}
	use_ok('CGI::Session::PureSQL');
};


my $dbh = DBI->connect($ENV{DBI_DSN}, $ENV{DBI_USER}, $ENV{DBI_PASS},
		    {RaiseError => 1, AutoCommit => 1});
ok(defined $dbh,'connect without transaction');

if ($dbh->{Driver}->{Name} eq 'Pg') {
	# Good, keep testing
}	
else {
	plan skip_all => 'Only Postgres is supported for testing now',
}


eval {
	$dbh->do("
    CREATE TABLE cgises_test (
        session_id 		 CHAR(32) NOT NULL
		, remote_addr		 inet
		, creation_time      timestamp
		, last_access_time   timestamp
		, duration		     interval
		, order_id			 int
		, order_id_exp_secs	 int
	)");
};
ok(!$@, 'created session table for testing');

#DBI->trace(1);

$ENV{REMOTE_ADDR} = '127.0.0.1';

# Test for default table name of 'sessions'
my $s;
eval { $s = CGI::Session::PureSQL->new(undef, {Handle=>$dbh}) };
ok (!$@, 'new() survives without TableName') or diag $@;

is ($CGI::Session::PureSQL::TABLE_NAME, 'sessions', 'session table name defaults to sessions');

# A warning will produced by the test about now. That's expected. -mls 10/27/03 

eval { $s = undef; };

eval { $s = CGI::Session::PureSQL->new(undef, {Handle=>$dbh,TableName=>'cgises_test'}) };
ok (!$@, 'new() survives') or diag $@;

ok($s->id, 'fetch session ID');

$s->param(order_id => 127 );

is( $s->param('order_id'), 127, 'testing param identity');

ok(!$s->expire(), 'expecting expire to return undef when no expire date was set' );

$s->expire("+10m");


is($s->expire(), 600, "expire() expected to return time in seconds");

$s->expire('order_id'=>'+10m');

my $sid = $s->id();

# save creation time to compare it later. 
my $ctime_from_first_session = $s->ctime;

ok($s->close, 'closing 1st session');

is($sid,$dbh->selectrow_array("SELECT session_id FROM cgises_test WHERE session_id = ?",{},$sid),
    "found row for closed session. (sid was: $sid)");    

#DBI->trace(1);
my $s2;
eval { $s2 = CGI::Session::PureSQL->new($sid, {Handle=>$dbh,TableName=>'cgises_test'}) };
ok($s2, 'created second test session');
DBI->trace(0);

is($sid,$dbh->selectrow_array("SELECT session_id FROM cgises_test WHERE session_id = ?",{},$sid),
    "found row (again) for closed session. (sid was: $sid)");    

is($s2->id(),$sid, 'checking session identity');

is($s2->param('order_id'),'127','checking ability to retrieve session data');

my $ctime_from_second_session = $s2->ctime;
is($ctime_from_first_session,$ctime_from_second_session, 'creation time remains the same');

eval { $s2->delete(); };
ok(!$@, 'delete() survives');

ok($s2->close, 'closing 2nd session');

ok ($dbh->do("DROP TABLE cgises_test"), 'dropping test table');
ok($dbh->disconnect, 'disconnecting');

