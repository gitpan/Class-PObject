

# $Id: 82fixISA_csv.t,v 1.1.2.2 2004/05/20 06:53:53 sherzodr Exp $

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
use Class::PObject::Test::ISA;

my $t = new Class::PObject::Test::ISA('csv', 
                        { Dir => File::Spec->catfile('data', 'isa', 'csv'),
                          Table => 'person' });
$t->run();

