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
        is_fragment=> { is_optional=>1, default=>1, doc=>"Set to 0 to add a paired end read. not enabled for now."},
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


sub execute {
my $self =shift;

unless(-f $self->data_file) {
    $self->error_message($self->data_file . " does not exist.");
    return;
}

#the shortuct here will make your eyes bleed
if(GSC::MiscAttribute->get(proprety_name=>'full_path', value=>$self->data_file)) {
    die "This external file has been referenced before! What's going on!?";
}
my $sls;
if($self->is_fragment) {
    $sls = GSC::RunLaneSolexa->create(is_external=>1, sample_name=>$self->sample_name, research_project=>$self->research_project, run_type=>'Standard', read_length=>$self->read_length);
}
   unless($sls) {
       $self->error_message("unable to create lane summary object for solexa external data");
       die;
   }
    
    my $data_path_object = Genome::MiscAttribute->create(entity_id=>$sls->seq_id, entity_class_name=>'Genome::InstrumentData', property_name=>'full_path' , value=>$self->data_file);
    unless($data_path_object) {
        $self->error_message("unable to make data_path in misc_attributes");
        die;
    }
    
    my $external_collaborator_object = Genome::MiscAttribute->create(entity_id=>$sls->seq_id, entity_class_name=>'Genome::InstrumentData', property_name=>'external_source_name' , value=>$self->external_data_source);

    

}


