

# $Id: 06basic_csv.t,v 1.3 2003/08/23 13:15:13 sherzodr Exp $

BEGIN {
    for ( "DBI", "DBD::CSV" ) {
        eval "require $_";
        if ( $@ ) {
            print "1..0 #Skipped: $_ is not installed\n";
            exit(0)
        }
    }
}


use Class::PObject::Test::Basic;
my $t = new Class::PObject::Test::Basic('csv', {Dir=>'data'});
$t->run();
