
# $Id: 74hasa_sqlite.t,v 1.1.2.1 2003/09/06 09:57:08 sherzodr Exp $

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

if ( -e $db ) {
    unlink($db)
}
my $dbh = DBI->connect("dbi:SQLite:dbname=$db", "", "");
eval {
    $dbh->do(qq|
        CREATE TABLE po_author (
            id INTEGER PRIMARY KEY,
            name VARCHAR(200)
        )|);
    $dbh->do(qq|
        CREATE TABLE po_article (
            id INTEGER PRIMARY KEY,
            title VARCHAR(200),
            author INTGER
        )|);
};

use Class::PObject::Test::HAS_A;
my $t = new Class::PObject::Test::HAS_A('sqlite', $db);
$t->run()

