

# $Id: 06basic_csv.t,v 1.4 2003/08/23 14:31:32 sherzodr Exp $

BEGIN {
    for ( "DBI", "DBD::CSV" ) {
        eval "require $_";
        if ( $@ ) {
            print "1..0 #Skipped: $_ is not installed\n";
            exit(0)
        }
    }
}


use File::Spec;
use Class::PObject::Test::Basic;

my $t = new Class::PObject::Test::Basic('csv', {Dir=>File::Spec->catfile('data', 'csv')});
$t->run();
