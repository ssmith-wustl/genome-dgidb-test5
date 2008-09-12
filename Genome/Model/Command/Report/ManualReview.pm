package Genome::Model::Command::Report::ManualReview;

use strict;
use warnings;

use Genome;

use Command;
use Data::Dumper;
use File::Temp;
use IO::File;

class Genome::Model::Command::Report::ManualReview
{
    is => 'Command',                       
    has => 
    [ 
        model_name => 
        {
            type => 'String',
            is_optional => 0,
            doc => "Model name we're working on",
        },
        snp_file =>
        {
            type => 'String',
            is_optional => 0,
            doc => "File of variants",    
        },
        output_dir =>
        {
            type => 'String',
            is_optional => 0,
            doc => "Directory to generate Manual Review reports",    
        },
        ref_seq_id =>
        {
            type => 'String',
            is_optional => 0,
            doc => "Ref seq id",    
        },
        library_name =>
        {
            type => 'String',
            is_optional => 1,
            doc => "Library name",    
        },
    ], 
};

############################################################

sub help_brief {   
    return;
}

sub help_synopsis { 
    return;
}

sub help_detail {
    return <<EOS 
    Creates a manual review directory from a given map list, snp file, and output dir.  This command must be run on a x64 system.
EOS
}

############################################################

sub execute { 
    my $self = shift;
$DB::single = 1;
    my $out_dir = $self->output_dir;
    my $snps = $self->snp_file;
    my $model_name = $self->model_name;
    my $ref_seq_id = $self->ref_seq_id || 'all_sequences';
    my $library_name = $self->library_name;
    
    my ($model) = Genome::Model->get("name like" => $model_name);
    
    return unless $model;
    print $model->name,"\n";
    
    my @maplists = $model->maplist_file_paths(ref_seq_id => $ref_seq_id, library_name => $library_name);
    
    unless (@maplists) {
        $self->error_message("Failed to find maplists!");
        return;
    }
    
    my $out_fh = File::Temp->new(UNLINK => 1);
    unless ($out_fh) {
        $self->error_message("Can not create temp file.\n");
        return;
    }

    for my $maplist (@maplists) {
        my $in_fh = IO::File->new($maplist,'r');
        unless($in_fh) {
            $self->error_message("Can not open file for reading '$maplist':  $!");
            return;
        }
        my @maps = <$in_fh>;
        $in_fh->close;
        print $out_fh @maps;
    }
    
    return Genome::Model::Tools::ManualReview->execute(map_list => $out_fh->filename, snp_file => $snps, output_dir => $out_dir);
}
############################################################


1;

