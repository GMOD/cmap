package CSHL::CMap::Apache;

# $Id: Apache.pm,v 1.1.1.1 2002-07-31 23:27:26 kycl4rk Exp $

=head1 NAME

CSHL::CMap::Apache - generic handler for cmap object viewers

=head1 SYNOPSIS

In your new derive "FooViewer.pm":

  package CSHL::CMap::Apache::FooViewer;
  use CSHL::CMap::Apache;
  use base 'CSHL::CMap::Apache';

  sub handler {
      my ( $self, $apr ) = @_;
      $apr->content_type('text/html');
      $apr->send_http_header;
      $apr->print('Yo');
      return OK; 
  }
  
  1;

In httpd.conf:

  <Location /foo>
      SetHandler  perl-script
      PerlHandler CSHL::CMap::Apache::FooViewer->super
  </Location>

=head1 DESCRIPTION

The base class for all other Apache "viewer" handlers.  Basically,
this wraps up the error handling and takes care of caching the
Template Toolkit and (optionally) the "page" objects.  Derived classes
can call "$self->template" for the template and just "die" at will as
this class will catch errors and display them correctly.

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.1.1.1 $)[-1];

use Apache;
use Apache::Constants;
use Data::Dumper;
use Error ':try';
use Apache::Constants;
use CSHL::CMap;
use CSHL::CMap::Constants;

use base 'CSHL::CMap';

#
# The template for formatting user error messages.
#
use constant ERROR_TEMPLATE => 'error.tmpl';

# ----------------------------------------------------
sub init {

=pod

=head2 init

Initializes the object.

=cut
    my ( $self, $config ) = @_;
    $self->params( $config, 'apr' ) || return undef;
    return $self; 
}

# ----------------------------------------------------
sub super( $$ ) {

=pod

=head2 super

The wrapper method called by Apache.  Here we make sure that we have
our globally cached objects, then we pass off the actual work of the
handler to the derived class's "handler" method.

=cut
    my $class = shift;
    my $apr   = Apache::Request->new( shift );
    my $self  = $class->new( apr => $apr );

    my $status;
    try {
        $status = $self->handler( $apr );
    }
    otherwise {
        my $e = shift;
        my $html;
        if ( my $t = $self->template ) {
            $t->process( 
                $self->error_template, 
                { 
                    error => $e, 
                    page  => $self->page,
                    debug => $self->debug,
                },
                \$html 
            ) or $html = $t->error;
        }
        else {
            $html = $e;
        }

        $apr->content_type('text/html');
        $apr->send_http_header;
        $apr->print( $html );
    }
    finally {
        $status ||= OK;
    };
    
    return $status;
}

# ----------------------------------------------------
sub apr { 

=pod

=head2 apr

Returns the Apache::Request object.

=cut
    my $self = shift;
    return $self->{'apr'};
}

# ----------------------------------------------------
sub debug { 

=pod

=head2 debug

Returns whether or not we're in "debug" mode.

=cut
    my $self = shift;

    unless ( defined $self->{'debug'} ) {
        $self->{'debug'} = $self->apr->dir_config('CMAP_DEBUG') || 0;
    }
}

# ----------------------------------------------------
sub error_template { 

=pod

=head2 error_template

Returns the correct template to use in formatting errors.

=cut
    my $self = shift;
    return ERROR_TEMPLATE;
}

# ----------------------------------------------------
sub template { 

=pod

=head2 template

Returns the Template Toolkit object.

=cut
    my $self = shift;

    unless ( $self->{'template'} ) {
        my $template_dir = $self->apr->dir_config('TEMPLATE_DIR') ||
                           TEMPLATE_DIR || '';

        $self->{'template'} = Template->new( 
            INCLUDE_PATH    => $template_dir,
            FILTERS         => {
                dump        => sub { Dumper( shift() ) },
                nbsp        => sub { my $s=shift; $s =~ s{\s+}{\&nbsp;}g; $s },
                commify     => \&CSHL::CMap::Utils::commify,
            }
        ) or $self->error(
            "Couldn't create Template object: ".Template->error()
        );
    }

    return $self->{'template'};
}

# ----------------------------------------------------
sub page { 

=pod

=head2 page

Returns the "page" object.  In the original Gramene project
(http://www.gramene.org/), we have a Perl object that handles
inserting appropriate page headers and footers.  This object can be
passed into the templates to print out these elements as necessary.

If you wish to have something like this, I'm sure you can glean the
basic ideas from Lincoln's "GramenePage.pm" module.  Then define the
"PAGE_OBJECT" with a "PerlSetVar" in your httpd.conf.  Otherwise, just
don't worry about it, and this method will never return anything.

=cut
    my $self = shift;

    unless ( defined $self->{'page'} ) {
        my $apr = $self->apr;
        if ( my $page_object = $apr->dir_config('PAGE_OBJECT') ) {
            $self->{'page'} = $page_object->new( $apr ) 
            or $self->error( qq[Couldn't create page object ("$page_object")] );
        }
        else {
            $self->{'page'} = ''; # define it to nothing
        }
    }

    return $self->{'page'};
}

1;

# ----------------------------------------------------
# If the fool would persist in his folly 
# He would become wise.
# William Blake
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

Copyright (c) 2002 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
