package Class::PObject::Template;

# $Id: Template.pm,v 1.7 2003/08/23 10:36:40 sherzodr Exp $

use strict;
use Log::Agent;

sub new {
    my $class = shift;
    $class    = ref($class) || $class;

    # What should be done if we detect odd number of arguments?
    # I'd say we should croak() right away. We don't want to
    # end-up with corrupted record in the database, whether the
    # code checks for error messages, or not!
    if ( @_ % 2 ) {
        logcroak "Odd number of arguments passed to new(). May result in corrupted data"
    }

    my $props = $class->__props();

    # object properties as represented internally by Class::PObject.
    # Whoever accesses this information from within their code will be shot
    my $self = {
        columns     => { },   # <-- holds key/value pairs
        _is_new     => 1
    };

    # DBD::CVS seems to keep all the column names in uppercase. This is a problem,
    # when the load() method calls new() with key/value pairs while creating an object
    # off the disk. So we first convert the @_ to a hashref
    my $args = { @_ };
    # and fill in 'columns' attribute of the class with their lower-cased names:
    while ( my ($k, $v) = each %$args ) {
        $self->{columns}->{lc $k}   = $v
    }

    # It's possible that new() was not given all the column/values. So we
    # detect the ones missing, and assign them 'undef'
    for my $colname ( @{$props->{columns}} ) {
        $self->{columns}->{$colname} ||= undef
    }

    # I'm not sure if 'datasource' should be mandatory. I'm open to
    # any suggestions. Some drivers may be able to recover 'datasource' on the fly,
    # without asking for expclicit definition.
    #unless ( defined $self->{datasource} ) {
        #$class->error("'datasource' is required");
        #return undef;
    #}

    # we may also check if the driver is indeed a valid one. However doing so
    # does not allow creating in-memory objects without valid driver. So let's leave
    # this test for related methods.

    bless($self, $class);

    # if _init() has been specified, we shoudl call it.
    if ( $self->UNIVERSAL::can('pobject_init') ) {
        $self->pobject_init
    }
    return $self
}




sub save {
    my $self  = shift;
    my $class = ref($self) || $self;

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






sub load {
    my $self  = shift;
    my $class = ref($self) || $self;

    # if we're called in void context, why bother?
    unless ( defined wantarray() ) {
        logtrc 2, "load() called in void context";
        return undef
    }

    # if we are not called in context where array value is expected,
    # we optimize our query by defining 'limit'
    unless ( wantarray() ) {
        $_[1]->{limit} = 1
    }

    my $props       = $self->__props();
    my $driver_obj  = $self->__driver();

    my $rows        = $driver_obj->load($class, $props, @_) or return;
    unless ( scalar @$rows ) {
        $self->errstr( $driver_obj->errstr );
        return ()
    }

    # if called in array context, we return an array of objects:
    if (  wantarray() ) {
        my @data_set = ();
        for ( @$rows ) {
            my $o = $self->new(%$_);
            $o->{_is_new} = 0;
            push @data_set, $o
        }
        return @data_set
    }

    # if we come this far, we're being called in scalar context
    my $o = $self->new( %{ $rows->[0] } );
    $o->{_is_new} = 0;
    return $o
}



sub remove {
    my $self    = shift;
    my $class   = ref $self;

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
    return $_[0]->{columns}
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
