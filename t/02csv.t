# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# $Id: 02csv.t,v 1.3 2003/06/08 20:58:57 sherzodr Exp $

use strict;
use Test;
use File::Spec;
for ( 'DBI', "DBD::CSV" ) {
  eval "require $_";
  if ( $@ ) {
    print "1..0 #Skipped: '$_' is not available\n";
    exit(0);
  }
}

plan( tests => 22 );

use Class::PObject;
ok(1);

pobject Person => {
  columns => [
    'id', 'name', 'email'
  ],
  driver => 'csv',
  datasource => {    
    Dir    => File::Spec->catfile('t', 'data', '02_csv'),
  }
};





#--------------------------------------------------------------------
# creating empty object
my $p1 = new Person();
ok($p1);

# defining column values
$p1->name('Sherzod'); 
$p1->email('sherzodr@handalak.com');

# checking if the object is updated respectively
ok($p1->name eq 'Sherzod');
ok($p1->email eq 'sherzodr@handalak.com');

# storing the data into disk:
my $new_id = $p1->save() or die $p1->error;
ok($new_id);

# destroying the object
undef($p1);



#--------------------------------------------------------------------
# trying to load that data off the disk (scalar context)
my $p2 = Person->load($new_id) or die "couldn't load $new_id: " . Person->error;

ok($p2);

#die Dumper($p2);

# checking the integrity of data
ok($p2->name eq 'Sherzod');
ok($p2->email eq 'sherzodr@handalak.com');
ok($p2->id  == $new_id);

# changing the e-mail address:
$p2->email('sherzodr@cpan.org');

# storing the data back into disk. Return value of save()
# should be the same as the id of the object
ok($p2->save() == $new_id);

# destroying the object
undef($p2);




#--------------------------------------------------------------------
# trying to load data off the disk (array context)
my @objects = Person->load($new_id);

# there should be only one object in the list
ok(@objects == 1);

my $p3 = $objects[0];

# checking if the returned object was of type 'Person'
ok(ref($p3) eq 'Person');

# checking the integrity of data
ok($p3->name eq 'Sherzod');
ok($p3->email eq 'sherzodr@cpan.org');
ok($p3->id  == $new_id);

# changing the name now:
$p3->name('Geek');

# storing the data back into disk. Return value of save()
# should be the same as the id of the object
ok($p3->save() == $new_id);

# destroying the object
undef($p3);






#--------------------------------------------------------------------
# trying to load the object again, this time to remove it for good
my $p4 = Person->load($new_id);
ok($p4);

ok($p4->remove);

# destroying object
undef($p4);







#--------------------------------------------------------------------
# trying to load previously deleted object. It should fail
my $p5 = Person->load($new_id);
ok($p5 ? 0 : 1);









#--------------------------------------------------------------------
# will it perform as expected in loop context
for ( 1..10 ) {
  my $p6 = new Person();
  $p6->name("Geek #$_");
  $p6->email("Geek-$_\@handalak.com");
  $p6->save();
}

# trying to load all the previously stored objects:
my @list = Person->load();
ok(@list == 10);

ok(Person->remove_all);


#--------------------------------------------------------------------
# checking if everything was really deleted
my $not_deleted = Person->load();
ok($not_deleted ? 0 : 1);




__END__;
