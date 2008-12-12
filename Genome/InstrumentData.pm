package Genome::InstrumentData;

use strict;
use warnings;

use Genome;

use Data::Dumper;
require Genome::Utility::FileSystem;

class Genome::InstrumentData {
    id_by => ['id'],
    table_name => <<EOS
    (
        select run_name id,
                sanger.run_name,
                'sanger' sequencing_platform,
                sanger.run_name seq_id,
                'unknown' sample_name,
                1 subset_name,
                'unknown' library_name
        from gsc_run\@oltp sanger

     union all

        select to_char(seq_id) id,
                solexa.run_name,
                'solexa' sequencing_platform,
                to_char(solexa.seq_id) seq_id, 
                solexa.sample_name sample_name,
                solexa.lane subset_name,
                solexa.library_name library_name
        from solexa_lane_summary\@dw solexa
        where run_type in ('Standard','Paired End Read 2')
    
     union all

        select to_char(x454.region_id) id,
                x454.run_name,
                '454' sequencing_platform,
                to_char(x454.region_id) seq_id, 
                nvl(x454.sample_name, x454.incoming_dna_name) sample_name, 
                x454.region_number subset_name,
                x454.library_name library_name
        from run_region_454\@dw x454
        
    ) idata
EOS
    ,
    is_abstract => 1,
    sub_classification_method_name => '_resolve_subclass_name',
    has => [
        sequencing_platform => { is => 'VARCHAR2', len => 255 },
        run_name            => { is => 'VARCHAR2', len => 500, is_optional => 1 },
        subset_name         => { is => 'VARCHAR2', len => 32, is_optional => 1, },
        sample_name         => { is => 'VARCHAR2', len => 255 },
        #sample              => { is => 'Genome::Sample', where => [ 'sample_name' => \'sample_name' ] },
        library_name        => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        seq_id => { is => 'VARCHAR2', len => 15, is_optional => 1 },
        events => { is => 'Genome::Model::Event', is_many => 1, reverse_id_by => "instrument_data" },
        full_name => { calculate_from => ['run_name','subset_name'], calculate => q|"$run_name/$subset_name"| },        
        name => {
            doc => 'This is a long version of the name which is still used in some places.  Replace with full_name.',
            is => 'String', 
            calculate_from => ['run_name','sample_name'], 
            calculate => q|$run_name. '.' . $sample_name| 
        },
    ],
    has_optional => [
        full_path => {
            via => 'attributes',
            to => 'value', 
            where => [ entity_class_name => 'Genome::InstrumentData', property_name => 'full_path' ],
            is_mutable => 1,
        },
    ],
    has_many_optional => [
        attributes => {
            is => 'Genome::MiscAttribute',
            reverse_id_by => '_instrument_data',
            where => [ entity_class_name => __PACKAGE__ ],
        },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

#< UR Methods >#
sub delete {
    my $self = shift;

    for my $attr ( $self->attributes ) {
        $attr->delete;
    }
    $self->SUPER::delete;

    return $self;
}

sub _resolve_subclass_name {
	my $class = shift;

	if (ref($_[0]) and $_[0]->isa(__PACKAGE__)) {
		my $sequencing_platform = $_[0]->sequencing_platform;
		return $class->_resolve_subclass_name_for_sequencing_platform($sequencing_platform);
	}
    elsif (my $sequencing_platform = $class->get_rule_for_params(@_)->specified_value_for_property_name('sequencing_platform')) {
        return $class->_resolve_subclass_name_for_sequencing_platform($sequencing_platform);
    }
	else {
		return;
	}
}

sub _resolve_subclass_name_for_sequencing_platform {
    my ($class,$sequencing_platform) = @_;
    my @type_parts = split(' ',$sequencing_platform);

    my @sub_parts = map { ucfirst } @type_parts;
    my $subclass = join('',@sub_parts);

    my $class_name = join('::', 'Genome::InstrumentData' , $subclass);
    return $class_name;
}

sub _resolve_sequencing_platform_for_subclass_name {
    my ($class,$subclass_name) = @_;
    my ($ext) = ($subclass_name =~ /Genome::InstrumentData::(.*)/);
    return unless ($ext);
    my @words = $ext =~ /[a-z]+|[A-Z](?:[A-Z]+|[a-z]*)(?=$|[A-Z])/g;
    my $sequencing_platform = lc(join(" ", @words));
    return $sequencing_platform;
}

#< Paths >#
sub create_data_directory_and_link {
    my $self = shift;

    my $data_path = $self->resolve_full_path;
    Genome::Utility::FileSystem->create_directory($data_path)
        or return;
    
    Genome::Utility::FileSystem->create_symlink($data_path, $self->data_link)
        or return;

    return $data_path;
}

sub _links_base_path {
    return '/gscmnt/839/info/medseq/instrument_data_links/';
}

sub data_link {
    return sprintf('%s/%s', _links_base_path(), $_[0]->id);
}

sub _data_base_path {
    return '/gscmnt/sata363/info/medseq/instrument_data/';
}

sub resolve_full_path{
    my $self = shift;

    return $self->full_path if $self->full_path;

    return $self->full_path( $self->_default_full_path );
}

sub _default_full_path {
    my $self = shift;
    sprintf('%s/%s', $self->_data_base_path, $self->id)
}
    

#< Dump to File System >#
sub dump_to_file_system {
    my $self = shift;
    $self->warning_message("Method 'dump_data_to_file_system' not implemented");
    return 1;
}

######
# Needed??
# WHY NOT USE RUN_NAME FROM THE DB????
sub old_name {
    my $self = shift;

    my $path = $self->full_path;

    my($name) = ($path =~ m/.*\/(.*EAS.*?)\/?$/);
    if (!$name) {
	   $name = "run_" . $self->id;
    }
    return $name;
}

1;

#$HeadURL$
#$Id$
