

# $Id: 11basic_mysql.t,v 1.4 2003/08/23 13:15:13 sherzodr Exp $

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



my $dbh = DBI->connect("dbi:mysql:$ENV{MYSQL_DB}", $ENV{MYSQL_USER}, $ENV{MYSQL_PASSWORD}, {PrintError=>0});
eval {
    $dbh->do(qq|
        CREATE TABLE po_author (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(200),
            email VARCHAR(200),
            url VARCHAR(200)
        )|);
    $dbh->do(qq|
        CREATE TABLE po_article (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
            title VARCHAR(200),
            author INT UNSIGNED NOT NULL,
            content TEXT 
        )|);
};

if ( $@ ) {
    print "1..0 #Skipped: $@\n";
    exit(0)
}

use Class::PObject::Test::Basic;
my $t = new Class::PObject::Test::Basic('mysql', {Handle=>$dbh});
$t->run();
