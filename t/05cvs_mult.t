# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# $Id: 05cvs_mult.t,v 1.3 2003/06/08 20:58:57 sherzodr Exp $


print "1..0 # Skipped: 'cvs' driver is buggy! To be fixed in next releases\n";
exit(0);

use strict;
use Test;
use Data::Dumper;
use File::Spec;
#BEGIN { plan tests => 21, todo=>[(1..21)]};
use Class::PObject;



ok(1);
#########################



# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# creating an Album and Music objects
pobject Album => {
  columns => ['id', 'title'],
  driver  => 'csv',  
  datasource => {
    Dir => File::Spec->catfile('t', 'data', '05_albums')
  }
};

pobject Song => {
  columns => ['id', 'title', 'artist', 'album_id'],
  driver    => 'csv',
  datasource => {
    Dir => File::Spec->catfile('t', 'data', '05_song'),
  }
};

#--------------------------------------------------------------------
# creating a new Album
my $album = new Album(title=>"The Best From Uzbekistan");
ok($album);
ok(my $album_id = $album->save);


#--------------------------------------------------------------------
# filling the album with songs
my @songs = (
  ["Jonimga Tegma", "Dado"],
  ["Sen Borsan",    "Setora"],
  ["Nozli Gulim",   "Shahzod"],
  ["Go'zal Yor",    "Ruslan Sharipov"],
  ["Kerak Emas",    "Bolalar"],
  ["Yolvorma",      "Rayxon"],
  ["Sen Yig'lama",  "Ravshan Sobirov"],
  ["Ketma",         "Ozoda"],
  ["Qaynona",       "Ozoda"]
);



for (my $i=0; $i < @songs; $i++ ) {
  my $song = new Song();
  $song->title($songs[$i]->[0]);
  $song->artist($songs[$i]->[1]);
  $song->album_id($album_id);
  ok( $song->save() );
}

#--------------------------------------------------------------------
# checking \%terms
my @favorites = Song->load({artist=>"Ozoda", album_id=>$album_id});
ok(@favorites == 2);

# checking 'limit'
my @the_favorite = Song->load(undef, {limit=>1});
#print Dumper(\@the_favorite);
ok(@the_favorite == 1);


#--------------------------------------------------------------------
# checking 'sort'and 'direction'
my @all = Song->load(undef, {sort=>'artist', direction=>'desc'});
ok(@all == 9);

# first song should be the one by Bolalar
ok($all[0]->title eq 'Nozli Gulim');

# for my visual satisfation, and NOT for Test::Harness
for (my $i=0; $i < @all; $i++) {
  my $s = $all[$i];
  printf("\t[%02d] - '%s' (%s)\n", $s->id, $s->title, $s->artist);
}


#--------------------------------------------------------------------
# checking both 'sort' and 'direction', as well as limit
@all = Song->load(undef, {sort=>'artist', direction=>'desc', limit=>2, offset=>4});
ok(@all == 2);
ok($all[0]->title eq "Sen Yig'lama");
ok($all[1]->title eq 'Ketma');


#--------------------------------------------------------------------
# cleaning up after ourself to make sure the environment will be ready
# if we decide to run the tests again
ok(Album->remove_all());
ok(Song->remove_all());
