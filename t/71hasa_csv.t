

# $Id$

BEGIN {
    for ( "DBI", "DBD::CSV", "SQL::Statement" ) {
        eval "require $_";
        if ( $@ ) {
            print "1..0 #Skipped: $_ is not installed\n";
            exit(0)
        }
    }
    if ( $SQL::Statement::VERSION < 1.005 ) {
        print "1..0 #Skipped: SQL::Statement 1.005 is required. Your version is $SQL::Statement::VERSION\n";
        exit(0)
    }
}

use File::Spec;
use Class::PObject::Test::HAS_A;

my $t = new Class::PObject::Test::HAS_A('csv', {Dir=>File::Spec->catfile('data', 'has_a', 'csv')});
$t->run();
