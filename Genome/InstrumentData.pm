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
         SELECT to_char(solexa.analysis_id) id,
               fc.run_name,
               'Genome::InstrumentData::Solexa' subclass_name,
               'solexa' sequencing_platform,
               to_char(solexa.analysis_id) seq_id,
               sam.full_name sample_name,
               (
                    case 
                        when solexa.index_sequence is null then to_char(solexa.lane) 
                        else to_char(solexa.lane) || '-' || solexa.index_sequence
                    end
               ) subset_name,
               lib.full_name library_name
          FROM GSC.index_illumina solexa 
          JOIN GSC.library_summary lib on lib.library_id = solexa.library_id
          JOIN GSC.organism_sample sam on sam.organism_sample_id = lib.sample_id
          JOIN GSC.flow_cell_illumina fc on fc.flow_cell_id = solexa.flow_cell_id
     UNION ALL
            SELECT 
               to_char(case when ri.index_sequence is null then ri.region_id else ri.seq_id end) id,
               r.run_name,
               'Genome::InstrumentData::454' subclass_name,
               '454' sequencing_platform,
               to_char(ri.seq_id) seq_id,
               s.full_name sample_name,
               (
                case
                    when ri.index_sequence is null then to_char(r.region_number)
                    else to_char(r.region_number) || '-' || ri.index_sequence
                end
               ) subset_name,
               lib.full_name library_name
           FROM GSC.run_region_454 r 
            JOIN GSC.region_index_454 ri on ri.region_id = r.region_id
            JOIN GSC.library_summary lib on lib.library_id = ri.library_id
            JOIN GSC.organism_sample s on s.organism_sample_id = lib.sample_id
     UNION ALL
        SELECT to_char(imported.id) id,
               'unknown' run_name,
               'Genome::InstrumentData::Imported' subclass_name,
               sequencing_platform,
               to_char(imported.id) seq_id,
               NVL(imported.sample_name, 'unknown') sample_name,
               subset_name,
               'unknown' library_name
          FROM imported_instrument_data imported 
     UNION ALL
        SELECT run_name id,
               sanger.run_name,
               'Genome::InstrumentData::Sanger' subclass_name,
               'sanger' sequencing_platform,
               sanger.run_name seq_id,
               NVL(sample.value, 'unknown') sample_name,
               '1' subset_name,
               NVL(library.value, 'unknown') library_name
          FROM gsc_run\@oltp sanger,
               misc_attribute sample,
               misc_attribute library
         WHERE sanger.run_name = sample.entity_id(+) AND
               sanger.run_name = library.entity_id(+) AND
               sample.entity_class_name(+) = 'Genome::InstrumentData::Sanger' AND
               sample.property_name(+) = 'sample_name' AND
               library.entity_class_name(+) = 'Genome::InstrumentData::Sanger' AND
               library.property_name(+) = 'library_name'
    ) idata
EOS
    ,
    is_abstract => 1,
    subclassify_by => 'subclass_name',
    #sub_classification_method_name => '_resolve_subclass_name',
    has => [
        sequencing_platform => { is => 'VARCHAR2', len => 255 },
        subclass_name       => { is => 'VARCHAR2', len => 255 },
        run_name            => { is => 'VARCHAR2', len => 500, is_optional => 1 },
        subset_name         => { is => 'VARCHAR2', len => 32, is_optional => 1, },
        sample_name         => { is => 'VARCHAR2', len => 255 },
        #sample              => { is => 'Genome::Sample', where => [ 'sample_name' => \'sample_name' ] },
        library_name        => { is => 'VARCHAR2', len => 255, is_optional => 1 },
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

sub from_cmdline {
    my $class = shift;
    my @obj;
    while (my $txt = shift) {
        eval {
            my $bx = UR::BoolExpr->resolve_for_string($class,$txt);
            my @matches = $class->get($bx);
            push @obj, @matches;
        };
        if ($@) {
            my @matches = $class->get($txt);
            push @obj, @matches;
        }
    }
    return @obj;
}

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
		my $sequencing_platform = $_[0]->subclass_name;
		return $class->_resolve_subclass_name_for_sequencing_platform($sequencing_platform);
	}
    elsif (my $sequencing_platform = $class->get_rule_for_params(@_)->specified_value_for_property_name('subclass_name')) {
        return $class->_resolve_subclass_name_for_sequencing_platform($sequencing_platform);
    }
	else {
		return;
	}
}

sub seq_id { shift->id }

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
    
    my $link = $self->data_link;
    unlink $link if -l $link;
    Genome::Utility::FileSystem->create_symlink($data_path, $link)
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
    return '/gscmnt/sata835/info/medseq/instrument_data/';
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

sub allocations {
    my $self = shift;

    my @allocations = Genome::Disk::Allocation->get(
                                                    owner_class_name => $self->class,
                                                    owner_id => $self->id,
                                                );
    return @allocations;
}

sub calculate_alignment_estimated_kb_usage {
    my $self = shift;
    return;
}

sub sample_type {
    my $self = shift;
    my $dna_type;
    my @dna = GSC::DNA->get(dna_name => $self->sample_name);
    if (@dna == 1) {
        
        if ($dna[0]->dna_type eq 'genomic dna') {
            return 'dna';
        } elsif ($dna[0]->dna_type eq 'pooled dna') {
            return 'dna';
        } elsif ($dna[0]->dna_type eq 'rna') {
            return 'rna';
        }
    }
    return;
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

sub create_mock {
    my $class = shift;
    return $class->SUPER::create_mock(subclass_name => 'Genome::InstrumentData', @_);
}


1;

#$HeadURL$
#$Id$
