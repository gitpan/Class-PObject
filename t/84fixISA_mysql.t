

# $Id: 84fixISA_mysql.t,v 1.1.2.1 2004/05/19 22:42:42 sherzodr Exp $

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

use Class::PObject::Test::ISA;
my $t = new Class::PObject::Test::ISA('mysql', \%dsn);
$t->run();
