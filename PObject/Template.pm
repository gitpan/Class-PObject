package Class::PObject::Template;

# $Id: Template.pm,v 1.16 2003/08/28 16:32:24 sherzodr Exp $

use strict;
use Log::Agent;
use vars ('$VERSION');

$VERSION = '1.02';

sub new {
    my $class = shift;
    $class    = ref($class) || $class;

    logtrc 2, "%s->new(%s)", $class, join ", ", @_;

    # What should be done if we detect odd number of arguments?
    # I'd say we should croak() right away. We don't want to
    # end-up with corrupted record in the database, whether the
    # code checks for error messages, or not!
    if ( @_ % 2 ) {
        logcroak "Odd number of arguments passed to new(). May result in corrupted data"
    }

    my $props = $class->__props();

    # object properties as represented internally by Class::PObject.
    # Whoever accesses this information from within their code should be shot
    my $self = {
        columns     => { @_ },   # <-- holds key/value pairs
        _is_new     => 1
    };

	bless($self, $class);

    # It's possible that new() was not given all the column/values. So we
    # detect the ones missing, and assign them 'undef'
    for my $colname ( @{$props->{columns}} ) {
        unless ( defined $self->{columns}->{$colname} ) {
            $self->{columns}->{$colname} = undef
        }
    }

    # we may also check if the driver is indeed a valid one. However doing so
    # does not allow creating in-memory objects without valid driver. So let's leave
    # this test for related methods.

    # if pobject_init() exists, we should call it
    if ( $self->UNIVERSAL::can('pobject_init') ) {
        logtrc 2, "calling pobject_init()";
        $self->pobject_init
    }
    return $self
}




sub save {
    my $self  = shift;
    my $class = ref($self) || $self;

    logtrc 2, "%s->save(%s)", $class, join ", ", @_;

    my $props = $self->__props();
    my $driver_obj = $self->__driver();

    # we now call the driver's save() method, with the name of the class,
    # all the props passed to pobject(), and column values to be stored
    my $rv = $driver_obj->save($class, $props, $self->{columns});
    unless ( defined $rv ) {
        $self->errstr($driver_obj->errstr);
        logerr $self->errstr;
        return undef
    }
    $self->id($rv);
    return $rv
}







sub fetch {
    my $self = shift;
    my ($terms, $args) = @_;
    my $class = ref($self) || $self;

    logtrc, "%s->fetch(%s)", $class, join ", ", @_;

    $terms ||= {};
    $args  ||= {};
    
    my $props  = $self->__props();
    my $driver = $self->__driver();

    my $ids = $driver->load_ids($class, $props, $terms, $args);

    require Class::PObject::Iterator;
    return Class::PObject::Iterator->new($class, $ids);
}








sub load {
    my $self  = shift;
    my ($terms, $args) = @_;
    my $class = ref($self) || $self;

    logtrc 2, "%s->load(%s)", $class, join ", ", @_;

    $terms ||= {};
    $args  ||= {};

    # if we're called in void context, why bother?
    unless ( defined wantarray() ) {
        return undef
    }

    # if we are not called in context where array value is expected,
    # we optimize our query by defining 'limit'
    unless ( wantarray() ) {
        $_[1]->{limit} = 1
    }

    my $props       = $self->__props();
    my $driver_obj  = $self->__driver();
    my $ids         = [];       # we first initialize an empty ID list

    # now, if we had a single argument, and that argument was not a HASH,
    # we assume we received an ID
    if ( $terms && (ref($terms)  ne 'HASH') && ($terms =~ /^\d+$/) ) {
        $ids = [ $terms ]

    } else {
        $ids        = $driver_obj->load_ids($class, $props, $terms, $args) or return

    }

    unless ( scalar @$ids ) {
        return ()
    }

    # if called in array context, we return an array of objects:
    if (  wantarray() ) {
        my @data_set = ();
        for my $id ( @$ids ) {
            my $row = $driver_obj->load($class, $props, $id) or next;
            my $o = $self->new(%$row);
            $o->{_is_new} = 0;
            push @data_set, $o
        }
        return @data_set
    }

    # if we come this far, we're being called in scalar context
    my $row = $driver_obj->load($class, $props, $ids->[0]) or return;
    my $o = $self->new( %$row );
    $o->{_is_new} = 0;
    return $o
}



sub remove {
    my $self    = shift;
    my $class   = ref $self;

    logtrc 2, "%s->remove()", $class;
    unless ( ref $self ) {
        logcroak "remove() used as a static method";
    }

    my $props       = $self->__props();
    my $driver_obj  = $self->__driver();

    # if 'id' field is missing, most likely it's because this particular object
    # hasn't been saved into disk yet
    unless ( defined $self->id) {
        logcroak "object is not saved into disk yet"
    }

    my $rv = $driver_obj->remove($class, $props, $self->id);
    unless ( defined $rv ) {
        $self->errstr($driver_obj->errstr);
        return undef
    }
    return $rv
}







sub remove_all {
    my $self = shift;
    my $class = ref($self) || $self;

    logtrc 2, "%s->remove_all(%s)", $class, join ", ", @_;

    my $props = $self->__props();
    my $driver_obj = $self->__driver();

    my $rv = $driver_obj->remove_all($class, $props, @_);
    unless ( defined $rv ) {
        $self->errstr($driver_obj->errstr());
        return undef
    }
    return 1
}






sub count {
    my $self = shift;
    my $class = ref($self) || $self;

    logtrc 2, "%s->count(%s)", $class, join ", ", @_;

    my $props      = $self->__props();
    my $driver_obj = $self->__driver();

    return $driver_obj->count($class, $props, @_)
}



sub errstr {
    my $self  = shift;
    my $class = ref($self) || $self;

    no strict 'refs';
    if ( defined $_[0] ) {
        ${ "$class\::errstr" } = $_[0]
    }
    return ${ "$class\::errstr" }
}




sub columns {
    my $self = shift;
    my $class = ref($self) || $self;

    logtrc 2, "%s->columns()", $class;

    return $self->{columns}
}







sub dump {
    my ($self, $indent) = @_;

    require Data::Dumper;
    my $d = Data::Dumper->new([$self], [ref $self]);
    $d->Indent($indent||2);
    $d->Deepcopy(1);
    return $d->Dump()
}





sub __props {
    my $self = shift;

    no strict 'refs';
    return ${ (ref($self) || $self) . '::props' }
}



sub __driver {
    my $self  = shift;

    my $props = $self->__props();
    my $pm = "Class::PObject::Driver::" . $props->{driver};

    # closure for getting and setting driver object
    my $get_set_driver = sub {
        no strict 'refs';
        if ( defined $_[0] ) {
            ${ "$pm\::__O" } = $_[0]
        }
        return ${ "$pm\::__O" }
    };

    my $driver_obj = $get_set_driver->();
    if ( defined $driver_obj ) {
        return $driver_obj
    }

    # if we got this far, it's the first time the driver is
    # required.
    eval "require $pm";
    if ( $@ ) {
        logcroak $@
    }
    $driver_obj = $pm->new();
    unless ( defined $driver_obj ) {
        $self->errstr($pm->errstr);
        return undef
    }
    $get_set_driver->($driver_obj);
    return $driver_obj
}

1;
