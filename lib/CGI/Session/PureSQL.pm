
package CGI::Session::PureSQL;
use strict;
use lib ('./blib/lib','../blib/lib');
use base qw(
    CGI::Session
    CGI::Session::ID::MD5
	CGI::Session::Serialize::SQLAbstract
);

# Load neccessary libraries below

use vars qw($VERSION $TABLE_NAME @ISA);

$VERSION = '0.52';
$TABLE_NAME = 'sessions';

sub store {
    my ($self, $sid, $options, $data) = @_;
	my $dbh = $self->PureSQL_dbh($options);


	my $session_exists;
	eval {
		($session_exists) = $dbh->selectrow_array(
			' SELECT session_id   FROM '.$TABLE_NAME.
			' WHERE session_id = ? FOR UPDATE',{},$sid);

	};
	if( $@ ) {
		$self->error("Couldn't acquire data on id '$sid'");
		return undef;
	}

    # Force the serializer to be SQLAbstract
    @ISA = qw(
        CGI::Session
        CGI::Session::ID::MD5
        CGI::Session::Serialize::SQLAbstract
        );


	eval { require SQL::Abstract; }; 
	if ($@) {
		$self->error('SQL::Abstract required but not found.');
		return undef;
	}
	my $sa = SQL::Abstract->new();

	eval {
		if ($session_exists) {
			 my($stmt, @bind) = 
				$sa->update(
					$TABLE_NAME, 
    				$self->freeze($data),
					{ session_id => $sid });
			$dbh->do($stmt,{},@bind);
		} 
		else {
            my $results = $self->freeze($data) ;
			my($stmt, @bind) = $sa->insert(
					$TABLE_NAME, $self->freeze($data)  );

			$dbh->do($stmt,{},@bind);

		}

	};

	if( $@ ) {
		$self->error("Error in session update on id '$sid'. $@");
		warn("Error in session update on id '$sid'. $@");
		return undef;
	}

	return 1;


}


sub retrieve {
    my ($self, $sid, $options) = @_;
    my $dbh = $self->PureSQL_dbh($options);
	my $drv = $dbh->{Driver}->{Name};

	my $data;

	my $epoch_func;
	if ($dbh->{Driver}->{Name} eq 'mysql') {
		$epoch_func = sub { sprintf 'UNIX_TIMESTAMP(%s)', $_[0] };
	}
	elsif ($dbh->{Driver}->{Name} eq 'Pg') {
		$epoch_func = sub { sprintf 'EXTRACT(EPOCH FROM %s)', $_[0] };
	}
	else {
		$self->error('Unsupported DBI driver. Currently only Pg and mysql are supported.'); 
		return undef;
	}

	
    eval {
    	$data = $dbh->selectrow_hashref(
    		' SELECT  *
				, '.$epoch_func->('creation_time')   			.' as creation_time
				, '.$epoch_func->('last_access_time')			.' as last_access_time
				, '.$epoch_func->("last_access_time + duration").'as end_time
			  FROM '.$TABLE_NAME.
			' WHERE session_id = '.$dbh->quote($sid)
	    );
	};
	if( $@ ) {
        $self->error("Couldn't acquire data on id '$sid'");
        return undef;
    }

    # Force the serializer to be SQLAbstract
    @ISA = qw(
        CGI::Session
        CGI::Session::ID::MD5
        CGI::Session::Serialize::SQLAbstract
        );
    
    return $self->thaw($data);
}



sub remove {
    my ($self, $sid, $options) = @_;
    my $dbh = $self->PureSQL_dbh($options);

	eval { $dbh->do( 'DELETE FROM '.$TABLE_NAME.' WHERE session_id = '.$dbh->quote($sid)) };
	if( $@ ) {
		warn $@;
		$self->error("Couldn't delete session row for: '$sid'");
		return undef;
	}
	else {
		return 1;
	}

    die "testing!";
    
}

# Called right before the object is destroyed to do cleanup
sub teardown {
	my ($self, $sid, $options) = @_;

	my $dbh = $self->PureSQL_dbh($options);

	# Call commit if we are in control of the handle
	# /and/ AutoCommit is not in effect 
	# /and/ the object is modified or deleted.
	if ($self->{PureSQL_Controls_Handle} &&
		!$dbh->{AutoCommit} && 
		(($self->{_STATUS} == MODIFIED() ) or ($self->{_STATUS} == DELETED()))) {
		$dbh->commit();
	}

	if ( $self->{PureSQL_Controls_Handle} ) {
		$dbh->disconnect();
	}

	return 1;
}


sub PureSQL_dbh {
    my ($self, $options) = @_;

    my $args = $options->[1] || {};

    if ( defined $self->{PureSQL_dbh} ) {
        return $self->{PureSQL_dbh};

    }

	if ( defined $args->{TableName} ) {
		$TABLE_NAME = $args->{TableName};
	}

    require DBI;

    $self->{PureSQL_dbh} = $args->{Handle} || DBI->connect(
                    $args->{DataSource},
                    $args->{User}       || undef,
                    $args->{Password}   || undef,
                    { RaiseError=>1, PrintError=>1, AutoCommit=>1 } );

    # If we're the one established the connection,
    # we should be the one who closes it
    $args->{Handle} or $self->{PureSQL_Controls_Handle} = 1;

    return $self->{PureSQL_dbh};

}


1;       

=pod

=head1 NAME

CGI::Session::PureSQL - Pure SQL driver with no embedded Perl stored in the database

=head1 SYNOPSIS
    
    use CGI::Session::PureSQL;
    $session = new CGI::Session("driver:PureSQL", undef, {Handle=>$dbh});

For more examples, consult L<CGI::Session> manual

=head1 DESCRIPTION

*Disclaimer* While this software is complete and includes a working test suite,
I'm marking it as a development release to leave room for feedback on the
interface. Until that happens, it's possible I may make changes that aren't
backwards compatible. You can help things along by communicating by providing
feedback about the module yourself.

CGI::Session::PureSQL is a CGI::Session driver to store session
data in a SQL table. Unlike the C<CGI::Session::PostgreSQL> driver, this
"pure SQL" driver does not serialize any Perl data structures to the database.

The means that you can access all the data in the session easily using standard
SQL syntax.

The downside side is that you have create the columns for any data you want to
store, and each field will have just one value: You can't store arbitrary data
like you can with the CGI::Session::PostgreSQL driver. However, you may already be in
the habit of writing applications which use standard SQL structures, so this
may not be much of a drawback. :) 

It currently requires the SQLAbstract serializer to work, which is included in
the distribution. If you specify another serializer it will be ignored. 

=head1 STORAGE

To store session data in SQL  database, you first need
to create a suitable table for it with the following command:

	-- This syntax for for Postgres; flavor to taste
    CREATE TABLE sessions (
        session_id 		 CHAR(32) NOT NULL,
		remote_addr		 inet,
		creation_time    timestamp, 
		last_access_time timestamp,
		duration		 interval
    );

You can also add any number of additional columns to the table,
but the above fields are required.

For any additional columns you add, if you would like to 
expire that column individually, you need to an additional
column to do that. For example, to add a column named C<order_id>
which you want to allow to be expired, you would add these two columns:

	order_id			int,
	order_id_exp_secs	int,

If you want to store the session data in other table than "sessions",
you will also need to specify B<TableName> attribute as the
first argument to new():

    use CGI::Session;

    $session = new CGI::Session("driver:PureSQL", undef,
						{Handle=>$dbh, TableName=>'my_sessions'});

Every write access to session records is done through PostgreSQL own row locking mechanism,
enabled by `FOR UPDATE' clauses in SELECTs or implicitly enabled in UPDATEs and DELETEs.

To write your own drivers for B<CGI::Session> refere L<CGI::Session> manual.

=head1 COPYRIGHT

Copyright (C) 2003 Mark Stosberg All rights reserved.

This library is free software and can be modified and distributed under the same
terms as Perl itself. 

=head1 CONTRIBUTING

Patches, questions and feedback are welcome. I maintain CGI::Session::PureSQL using
darcs, a CVS alternative ( http://www.darcs.net/ ). My darcs archive is here:
http://mark.stosberg.com/darcs_hive/puresql

=head1 AUTHOR

Mark Stosberg <mark@summersault.com>

=head1 SEE ALSO

=over 4

=item *

L<CGI::Session|CGI::Session> - CGI::Session manual

=item *

L<CGI::Session::Tutorial|CGI::Session::Tutorial> - extended CGI::Session manual

=item *

L<CGI::Session::CookBook|CGI::Session::CookBook> - practical solutions for real life problems

=item *

B<RFC 2965> - "HTTP State Management Mechanism" found at ftp://ftp.isi.edu/in-notes/rfc2965.txt

=item *

L<CGI|CGI> - standard CGI library

=item *

L<Apache::Session|Apache::Session> - another fine alternative to CGI::Session

=back

=cut



