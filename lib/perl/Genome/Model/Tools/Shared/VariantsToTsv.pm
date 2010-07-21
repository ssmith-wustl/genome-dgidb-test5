package Genome::Model::Tools::Shared::VariantsToTsv;

use Genome;
use strict;
use warnings;

class Genome::Model::Tools::Shared::VariantsToTsv {
    is => 'Command',
    has_many_input => [
        input_files             => { is => 'FileName', shell_args_position => 1, doc => 'variant detector results' },
    ],
    has_optional_output => [
        output_file             => { is => 'FileName', doc => 'converted tsv output' },
        assembly_project_name   => { is => 'FileName', doc => 'the name of the group of reads ("assembly project"), by default extracts from the input file name(s)' },
    ],
    has_abstract_constant => [
        tool_name               => { is => 'Text', doc => 'the name of the tool (polyphred, polyscan, etc.) with a corresponding MG::IO::* module to do the conversion.', is_class_wide => 1 },
    ],
    doc => "convert output to a standard tab-separated file format",
};

sub help_brief {
    shift->get_class_object->doc;
}

sub help_synopsis {
    my $self = shift;
    return "gmt " . $self->tool_name . " to-tsv f1 f2 f3 >my.tsv\n";
}

sub tool_name {
    die "Failed to implement tool_name to match a valid MG::IO::*. in " . shift->class;
}

sub help_detail {
    return <<EOS;
EOS
}

sub execute {
    my $self = shift;
    
    my @input_files = $self->input_files;
    my $combined_input_file = $self->ouput_file;
    my ($assembly_project_name) = $self->assembly_project_name;
    
    my $fh = IO::File->new(">$combined_input_file");
    
    # Create parsers for each file, append to running lists
    # TODO eliminate duplicates!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    for my $file (@input_files) {
        #TODO make sure assembly project names are going to be kosher
        ($assembly_project_name) ||= $file =~ /\/([^\.\/]+)\.poly(scan|phred)\.(low|high)$/;  
        my $param = lc($self->tool_name);
        my $type = ucfirst(lc($self->tool_name));
        my $module = "MG::IO::$type";
        my $parser = $module->new($param => $file,
                                  assembly_project_name => $assembly_project_name
                                 );
        my ($snps, $indels) = $parser->collate_sample_group_mutations;

        # Print all of the snps and indels to the combined input file
        for my $variant (@$snps, @$indels) {
            $fh->print( join("\t", map{$variant->{$_} } $self->combined_input_columns ) );
            $fh->print("\n");
        }
    }

    $fh->close;

    unless (-s $combined_input_file) {
        $self->error_message("Combined input file does not exist or has 0 size in setup_input");
        die;
    }

    my $sorted_file = "$combined_input_file.temp";

    # Sort by chromosome, position, sample... TODO: derive these numbers from columns sub
    system("sort -gk1 -gk2 -k4 $combined_input_file > $sorted_file");

    unless(-s $sorted_file) {
        $self->error_message("Failed to sort combined input file: $combined_input_file into $sorted_file");
        die;
    }
    
    unlink($combined_input_file);
    if(-s $combined_input_file) {
        $self->error_message("Failed to unlink combined input file: $combined_input_file");
        die;
    }
    
    cp($sorted_file, $combined_input_file);
    unless(-s $combined_input_file) {
        $self->error_message("Failed to copy sorted file: $sorted_file back to combined input file: $combined_input_file");
        die;
    }

    unlink($sorted_file);
    
    return 1;
}

1;

