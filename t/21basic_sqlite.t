

# $Id$

BEGIN {
    for ( "DBD::SQLite" ) {
        eval "require $_";
        if ( $@ ) {
            print "1..0 #Skipped: $_ is not available\n";
            exit(0)
        }
    }
}

require File::Spec;
my $db = File::Spec->catfile('data', 'basic', 'sqlite');

use Class::PObject::Test::Basic;
my $t = new Class::PObject::Test::Basic('sqlite', $db);
$t->run()

