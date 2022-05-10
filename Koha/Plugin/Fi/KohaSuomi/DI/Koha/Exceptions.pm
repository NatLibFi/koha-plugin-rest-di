package Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions;

use Modern::Perl;

use Exception::Class (

    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::BadParameter' => {
        isa => 'Koha::Exception',
        description => 'A bad parameter was given',
        fields => ['parameter'],
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::MissingParameter' => {
        isa => 'Koha::Exception',
        description => 'A required parameter is missing',
        fields => ["parameter"],
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::UnknownObject' => {
        isa => 'Koha::Exception',
        description => 'Object cannot be found or is not known',
    },
);

use Mojo::JSON;
use Scalar::Util qw( blessed );

=head1 NAME

Koha::Exceptions

=head1 API

=head2 Class Methods

=head3 rethrow_exception

    try {
        # ..
    } catch {
        # ..
        Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::rethrow_exception($e);
    }

A function for re-throwing any given exception C<$e>. This also includes other
exceptions than Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions.

=cut

sub rethrow_exception {
    my ($e) = @_;

    die $e unless blessed($e);
    die $e if ref($e) eq 'Mojo::Exception'; # Mojo::Exception is rethrown by die
    die $e unless $e->can('rethrow');
    $e->rethrow;
}

=head3 to_str

A function for representing any given exception C<$e> as string.

C<to_str> is aware of some of the most common exceptions and how to stringify
them, however, also stringifies unknown exceptions by encoding them into JSON.

=cut

sub to_str {
    my ($e) = @_;

    return (ref($e) ? ref($e) ." => " : '') . _stringify_exception($e);
}

sub _stringify_exception {
    my ($e) = @_;

    return $e unless blessed($e);

    # Stringify a known exception
    return $e->to_string      if ref($e) eq 'Mojo::Exception';
    return $e->{'msg'}        if ref($e) eq 'DBIx::Class::Exception';
    return $e->error          if $e->isa('Koha::Exception');

    # Stringify an unknown exception by attempting to use some methods
    return $e->to_str         if $e->can('to_str');
    return $e->to_string      if $e->can('to_string');
    return $e->error          if $e->can('error');
    return $e->message        if $e->can('message');
    return $e->string         if $e->can('string');
    return $e->str            if $e->can('str');

    # Finally, handle unknown exception by encoding it into JSON text
    return Mojo::JSON::encode_json({%$e});
}

1;
