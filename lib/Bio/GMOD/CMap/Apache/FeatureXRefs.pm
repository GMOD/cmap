package Bio::GMOD::CMap::Apache::FeatureXRefs;

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.0 $)[-1];

use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Data;
use base 'Bio::GMOD::CMap::Apache';
use Data::Dumper;


sub handler {

    my ( $self, $apr ) = @_;
    my $feature_acc = $apr->param('feature_acc') || $apr->param('feature_aid')
      or die 'No accession id';

    $self->data_source( $apr->param('data_source') ) or return $self->error();
    my $data = $self->data_module;
    my $feature = $data->feature_detail_data( feature_acc => $feature_acc )
      or return $self->error( $data->error );

    my $json="";
    if ( @{ $feature->{'xrefs'} || [] } ) {
        my @jsonArr;
        foreach my $xref (@{$feature->{'xrefs'}}) {
            my $xref_name = $xref->{'xref_name'};
            my $xref_url = $xref->{'xref_url'};
            push(@jsonArr, sprintf('{"xref_name":"%s", "xref_url":"%s"}', $xref_name, $xref_url));
        }
	if(scalar(@jsonArr)) {
	    $json = '[' . join(",", @jsonArr) . ']';
	} else {
	    $json = '{}';
        }    
    }
    print $apr->header( -type => 'application/json', -cookie => $self->cookie ), $json;
    return 1;
}

1;
