package Class::PObject::Iterator;

# $Id: Iterator.pm,v 1.2 2003/08/26 19:56:30 sherzodr Exp $

use strict;
use Carp 'croak';
use vars ('$VERSION');

$VERSION = '0.01';

sub new {
    my $class = shift;
    $class    = ref($class) || $class;

    my $self = {
        pobject     => $_[0],
        data_set    => $_[1],
        next_pointer=> 0,
        last_ptr    =>  scalar(@{$_[1]})-1
    };

    bless $self, $class;
}

sub DESTROY { 
    my $self = shift;

    $self->finish()
}

sub next {
    my $self = shift;

    my $next_id = $self->{data_set}->[ $self->{next_ptr}++ ];
    unless ( defined $next_id ) {
        return undef
    }
    return $self->{pobject}->load($next_id)
}



sub size {
    my $self = shift;

    return $self->{last_ptr} - $self->{next_ptr} + 1
}



sub reset {
    my $self = shift;

    $self->{next_ptr} = 0;
    $self->{last_ptr}  = scalar( @{ $self->{data_set} } ) - 1
}


sub push {
    my $self = shift;

    unless ( @_ ) {
        croak "push() usage error"
    }
    push @{$self->{data_set}}, $_[0];
    $self->{last_ptr}++
}


sub finish {
    my $self = shift;

    $self->{data_set} = undef;
    $self->{pobject}  = undef;
}



sub dump {
    my $self = shift;

    require Data::Dumper;
    my $d = new Data::Dumper([$self], [ref $self]);
    return $d->Dump
}



1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Class::PObject::Iterator - Incremental object loader for Class::PObject

=head1 SYNOPSIS

    use Class::PObject::Iterator;
    my $iter = new Class::PObject::Iterator($driver, \@ids);

    while ( my $obj = $iter->fetch ) {
        ...
    }

=head1 DESCRIPTION

Class::PObject::Iterator is a stand-alone iterator class initially used
by L<Class::PObject|Class::PObject> when you call C<fetch()> method
on a pobject.

=head1 METHODS

=over 4

=item C<new($pobject, \@ids)>

Constructor method. Accepts two arguments - name of the class, and list of ids.
Returns Class::PObject::Iterator object. You normally never will have to call C<new()>
yourself, because when you call C<fetch()> method on your $pobject it will return pre-initialized
iterator object.


=item C<next()>

When called on an iterator object, it will return the next object from the stack.
Remember, it will not return the object id, but it will return fully initialized pobject.

=item C<size()>

Returns size of the current stack. This number decrements by one each time C<next()> is called,
to reflect how many more elements are left in the data set.

=item C<reset()>

Resets the internal data set pointer to the beginning of the data set. This means, no matter
how far you have been into the stack, after you call C<reset()>, the next time you call
C<next()> method, it will return the object from the beginning of the stack.

=item C<push($idx)>

Pushes a new object id to the end of the current stack.

=item C<finish()>

Clears up the stack and other related data from the object. C<finish()> will be called for you
automatically once the iterator object exits the scope. You normally will not need to call this
method, for iterator object clears up all the remaining stack before it exits its scope. However,
this method may be handy if you are planning to C<push()> more data sets to the iterator object
and want to start from clean data set:

    $iterator->finish();
    for ( @inx ) {
        $iterator->push($_)
    }

=back


=head1 SEE ALSO

L<Class::PObject>

=head1 AUTHOR

Sherzod B. Ruzmetov, E<lt>sherzodr@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Sherzod B. Ruzmetov.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
