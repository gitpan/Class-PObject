

# $Id: Makefile.PL,v 1.11 2003/08/27 08:43:41 sherzodr Exp $

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    NAME	       	=> 'Class::PObject',
    VERSION_FROM	=> 'PObject.pm',
    PREREQ_PM	  	=> {
	    'Storable'      => 0,
	    'IO::Dir'       => 0,
	    'Test::More'    => 0,
	    'Log::Agent'    => 0
    },
    ABSTRACT	    => "Simple framework for programming persistent objects",
    AUTHOR	        => "Sherzod B. Ruzmetov <sherzodr\@cpan.org>"
);



package MY;

sub postamble {
	return <<'TAG';
realclean::
	$(RM_RF) data
TAG
}

sub libscan {
	my (undef, $path) = @_;
	return '' if $path =~ m/CVS/;
	return $path
}
