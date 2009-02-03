package Genome::Model::Command::Build::CombineVariants::VerifyAndFixAssembly::SingleAssembly;

use strict;
use warnings;
use above 'Genome';
use File::Copy 'cp';

class Genome::Model::Command::Build::CombineVariants::VerifyAndFixAssembly::SingleAssembly {
    is => 'Command',
    has => [
        assembly_name => { 
            is => 'String', 
            doc => 'Assembly to check' 
        },
        assembly_directory => { 
            is => 'String', 
            doc => 'Assembly project directory' 
        },
        ace_file => { 
            is => 'String', 
            doc => 'Ace file to check' 
        },
    ],
};

sub help_brief {
    "Verifies the correctness of an assembly and fixes them in various ways where incorrect for the 3730 pipeline.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model build verify-and-fix-assembly single-assembly --assembly_name some_name --assembly-directory /some/assembly/dir --ace-file some.ace 
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;
    
    my $assembly_directory = $self->assembly_directory;
    my $ace_file = $self->ace_file;
    unless (-d $assembly_directory){
        $self->error_message("project directory $assembly_directory does not exist or is not a directory");
    }
    unless (-e $ace_file){
        $self->error_message("ace file $ace_file does not exist");
    }

    my $ace_checker = $self->validate_ace($ace_file);

    my $contig_count = $ace_checker->contig_count;

    if ($contig_count==1){
        $self->status_message("ace contig count verified");
        return 1;
    }else{

        $self->status_message("ace contig count >1 : $contig_count contigs, remaking");

        my $remade_ace_file = $self->remake_ace_file_with_one_contig;

        my $ace_checker = $self->validate_ace($remade_ace_file);

        my $contig_count = $ace_checker->contig_count;

        if ($contig_count==1){
            $self->status_message("ace contig count verified");
            return 1;
        }else{
            $self->error_message("failed to recreate ace file w/ one contig");
            die;
        }
        cp($ace_file, "$ace_file.original.bak");
        cp($remade_ace_file, $ace_file);
        return 1;
    }
}

sub validate_ace{
    my $self = shift;
    my ($ace_file) = @_;
    my $ace_checker = Genome::Utility::AceSupportQA->create(
        fix_invalid_files => 1,
    );
    my $check = $ace_checker->ace_support_qa($ace_file);
    if (ref $check){
        $self->error_message("invalid files in ace/assembly_dir");
        die;
    }elsif( $check == 1){
        $self->status_message("ace file reads and refseq verified");
    }else{
        $self->error_messgae("ace file refseq invalid!");
        die;
    } 
    return $ace_checker;
}

sub remake_ace_file_with_one_contig{
    my $self = shift;
    my $assembly_directory = $self->assembly_directory;
    my $ap_name = $self->assembly_name;
    my $ap = GSC::AssemblyProject->get(assembly_project_name => $ap_name); 
    unless ($ap){
        self->error_message("no assembly project for $ap_name");
        die;
    }
    my $new_ace = $ap->recreate_ace_file( project_dir => $assembly_directory, no_mask =>1,  no_control => 1);
    unless ($new_ace){
        $self->error_message( "failed to recreate ace file for $ap_name in $assembly_directory" );
        die;
    }
    return $new_ace;
}

1;
