#!/usr/bin/perl

# $Id: Makefile.PL,v 1.4 2003/06/08 23:36:17 sherzodr Exp $

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

sub MY::postamble {
  return <<'TAG';
realclean::
	$(RM_RF) t/data
TAG
}

WriteMakefile(
    NAME	       	=> 'Class::PObject',
    VERSION_FROM	=> 'PObject.pm',
    PREREQ_PM	  	=> {
        'Data::Dumper'  => 0, 
        'File::Spec'    => 0,
        'IO::Dir'       => 0
      },
	ABSTRACT	   => 'Persistent Object Framework in Per',
	AUTHOR		   => 'Sherzod Ruzmetov <sherzodr@cpan.org>'
);


print <<MSG;
Make sure to read 'INSTALL' for details on running 'mysql' and 'csv' tests.
MSG

