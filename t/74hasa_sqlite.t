

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
my $db = File::Spec->catfile('data', 'has_a', 'sqlite');
use Class::PObject::Test::HAS_A;
my $t = new Class::PObject::Test::HAS_A('sqlite', $db);
$t->run()

