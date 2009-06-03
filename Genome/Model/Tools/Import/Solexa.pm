package Genome::Model::Tools::Import::Solexa;

use strict;
use warnings;

use Genome;
use Command;


class Genome::Model::Tools::Import::Solexa {
    is => 'Command',
    has => [ 
        data_file=> {},
        sample_name =>{},
        research_project => {},
        external_data_source=> {},
        read_length=> {},
        lane => {
                 is => 'Number',
                 default_value => 1,
                 doc => 'The lane this data came from.(default_value=1)',
             },
        is_fragment=> { is_optional=>1, default=>1, doc=>"Set to 0 to add a paired end read. not enabled for now."},
    ],
    has_optional => [
                     _seq_id => {
                                is => 'Number',
                                doc => 'The id for the new sequence item',
                            },
                     _run_lane_solexa => {
                                         calculate_from => '_seq_id',
                                         calculate => q|
                                               return GSC::RunLaneSolexa->get($_seq_id);
                                           |,
                                     },
                 ],
};


sub help_brief {
    "Make the necessary db entries to allow external data into genome model";
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
need to put help synopsis here
EOS
}

sub help_detail {
    my $self = shift;
    return <<"EOS"
First pass at a tool which imports data. since we have restricted read length to be not null, this tool will only handle fastqs or the original .txt style files for now--
EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return unless $self;

    if ($self->__errors__) {
        my @__errors___tags = $self->__errors__;
        my $error_message = 'Invalid object: ' ."\n";
        for my $tag (@__errors___tags) {
            $error_message .= $tag->desc ."\n";
        }
        $self->error_message($error_message);
        $self->delete;
        die($error_message);
    }
    return $self;
}


sub execute {
    my $self =shift;

    unless(-f $self->data_file) {
        $self->error_message($self->data_file . " does not exist.");
        return;
    }

    #the shortuct here will make your eyes bleed
    if (Genome::MiscAttribute->get(property_name=>'full_path', value=>$self->data_file)) {
        die "This external file has been referenced before! What's going on!?";
    }
    my $sls;
    if ($self->is_fragment) {
        $sls = GSC::RunLaneSolexa->create(
                                          is_external=>1,
                                          sample_name=>$self->sample_name,
                                          research_project=>$self->research_project,
                                          run_type=>'Standard',
                                          read_length=>$self->read_length,
                                          lane=>$self->lane,
                                      );
    }
    unless($sls) {
        $self->error_message("unable to create lane summary object for solexa external data");
        die;
    }
    $self->_seq_id($sls->id);

    my $data_path_object = Genome::MiscAttribute->create(entity_id=>$sls->seq_id, entity_class_name=>'Genome::InstrumentData', property_name=>'full_path' , value=>$self->data_file);
    unless($data_path_object) {
        $self->error_message("unable to make data_path in misc_attributes");
        die;
    }

    my $external_collaborator_object = Genome::MiscAttribute->create(entity_id=>$sls->seq_id, entity_class_name=>'Genome::InstrumentData', property_name=>'external_source_name' , value=>$self->external_data_source);
    unless($external_collaborator_object) {
        $self->error_message("unable to make external_source_name in misc_attributes");
        die;
    }
    return 1;
}


