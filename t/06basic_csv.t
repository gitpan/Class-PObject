

# $Id: 06basic_csv.t,v 1.5 2003/08/27 08:44:02 sherzodr Exp $

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
use Class::PObject::Test::Basic;

my $t = new Class::PObject::Test::Basic('csv', {Dir=>File::Spec->catfile('data', 'csv')});
$t->run();
