

# $Id$

BEGIN {
    for ( "DBI", "DBD::mysql" ) {
        eval "require $_";
        if ( $@ ) {
            print "1..0 #Skipped: $_ is not available\n";
            exit(0)
        }
    }
    unless ( $ENV{MYSQL_DB} && $ENV{MYSQL_USER} ) {
        print "1..0 #Skipped: Read INSTALL for details on running mysql-related tests";
        exit(0)
    }
}

my %dsn = (
    DSN => "dbi:mysql:$ENV{MYSQL_DB}",
    User => $ENV{MYSQL_USER},
    Password => $ENV{MYSQL_PASSWORD}
);

use Class::PObject::Test::HAS_A;
my $t = new Class::PObject::Test::HAS_A('mysql', \%dsn);
$t->run();
