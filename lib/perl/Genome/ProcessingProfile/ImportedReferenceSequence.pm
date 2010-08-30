package Genome::ProcessingProfile::ImportedReferenceSequence;

use strict;
use warnings;

use File::Spec;
use File::Temp;
use Genome;

class Genome::ProcessingProfile::ImportedReferenceSequence {
    is => 'Genome::ProcessingProfile',
    doc => "this processing profile does the file copying and indexing required to import a reference sequence fasta file"
};

sub _resolve_disk_group_name_for_build {
    return 'info_apipe_ref';
}

sub _execute_build {
    my ($self, $build) = @_;
    my $model = $build->model;

    if(!$model) {
        $self->error_message("Couldn't find model for build id " . $build->build_id . ".");
        return;
    }

    my $fasta_size = -s $build->fasta_file;
    unless(-e $build->fasta_file && $fasta_size > 0) {
        $self->error_message("Reference sequence fasta file \"" . $build->fasta_file . "\" is either inaccessible, empty, or non-existent.");
        return;
    }

    my $four_gigabytes = 4_294_967_296;
    if($fasta_size >= $four_gigabytes) {
        my $error = "Reference sequence fasta file \"". $build->fasta_file . "\" is larger than 4GiB.  In order to accommodate " .
                    "BWA, reference sequence fasta files > 4GiB are not supported.  Such sequences must be broken up and each chunk must " .
                    "have its own build and model(s).  Support for associating multiple fastas with a single reference model is " .
                    "desired but will require modifying the alignment code.";
        $self->error_message($error);
        return;
    }

    my $build_directory = $build->data_directory;
    my $output_directory = File::Temp->newdir(
        "tmp_XXXXX",
        DIR     => $build_directory,
        CLEANUP => 1,
    );
    chmod(0775, $output_directory); #so can be manually cleaned up by others if need be

    $self->status_message("Copying fasta");
    my $fasta_file_name = File::Spec->catfile($output_directory, 'all_sequences.fa');
    
    #If an error occurs here about refusing to write to an existing file, that was most likely on a re-run of the build
    #and the original error can be found earlier in the logs.  To restart, clear files out of the build directory.
    unless (Genome::Utility::FileSystem->copy_file($build->fasta_file, $fasta_file_name)) {
        $self->error_message('Failed to copy "' . $build->fasta_file . '" to "' . $fasta_file_name . '.');
        return;
    }

    $self->status_message("Making bases files from fasta.");
    my $rv = $self->_make_bases_files($fasta_file_name, $output_directory);

    unless($rv) {
        $self->error_message('Making bases files failed.');
        return;
    }

    $self->status_message("Doing bwa indexing.");
    my $bwa_index_algorithm = ($fasta_size < 11_000_000) ? "is" : "bwtsw";

    my $bwa_path = Genome::Model::Tools::Bwa->path_for_bwa_version(Genome::Model::Tools::Bwa->default_version);

    my $bwa_cmd = sprintf('%s index -a %s %s', $bwa_path, $bwa_index_algorithm, $fasta_file_name);
    $rv = Genome::Utility::FileSystem->shellcmd(
        cmd => $bwa_cmd,
        input_files => [$fasta_file_name],
    );

    unless($rv) {
        #Really, shellcmd dies in most failure circumstances so this code is not expected to run
        $self->error_message('bwa indexing failed');
        return;
    }

    $self->status_message("Doing bowtie indexing.");
    my $bowtie_file_stem = File::Spec->catfile($output_directory, 'all_sequences.bowtie');

    my $bowtie_path = Genome::Model::Tools::Bowtie->path_for_bowtie_version(Genome::Model::Tools::Bowtie->default_version); 

    my $bowtie_cmd = sprintf('%s-build %s %s', $bowtie_path, $fasta_file_name, $bowtie_file_stem);
    $rv = Genome::Utility::FileSystem->shellcmd(
        cmd => $bowtie_cmd,
        input_files => [$fasta_file_name],
        output_files => ["$bowtie_file_stem.1.ebwt","$bowtie_file_stem.2.ebwt","$bowtie_file_stem.3.ebwt","$bowtie_file_stem.4.ebwt","$bowtie_file_stem.rev.1.ebwt","$bowtie_file_stem.rev.2.ebwt"],    #hardcoding expected names
    );

    unless($rv) {
        $self->error_message('bowtie-build failed.');
        return;
    }


    $self->status_message("Doing maq fasta2bfa.");
    my $bfa_file_name = File::Spec->catfile($output_directory, 'all_sequences.bfa');

    my $maq_path = Genome::Model::Tools::Maq->path_for_maq_version('0.7.1'); #It's lame to hardcode this--but no new versions expected

    my $maq_cmd = sprintf('%s fasta2bfa %s %s', $maq_path, $fasta_file_name, $bfa_file_name);
    $rv = Genome::Utility::FileSystem->shellcmd(
        cmd => $maq_cmd,
        input_files => [$fasta_file_name],
        output_files => [$bfa_file_name],
    );

    unless($rv) {
        $self->error_message('maq fasta2bfa failed.');
        return;
    }

    $self->status_message("Doing samtools faidx.");

    my $samtools_path = Genome::Model::Tools::Sam->path_for_samtools_version(); #uses default version if none passed

    my $samtools_cmd = sprintf('%s faidx %s', $samtools_path, $fasta_file_name);
    $rv = Genome::Utility::FileSystem->shellcmd(
        cmd => $samtools_cmd,
        input_files => [$fasta_file_name],
    );

    unless($rv) {
        $self->error_message('samtools faidx failed.');
        return;
    }


    $self->status_message('Promoting files to final location.');
    for my $staged_file (glob($output_directory . '/*')) {
        my ($vol, $dir, $file_base) = File::Spec->splitpath($staged_file);
        my $final_file = join('/', $build_directory, $file_base);
        rename($staged_file, $final_file);
    }

    # Reallocate to amount of space actually consumed if the build has an associated allocation and that allocation
    # has an absolute path the same as this build's data_path
    $self->status_message("Reallocating.");
    if (defined($build->disk_allocation)) {
        unless($build->disk_allocation->reallocate) {
            $self->error_message("Reallocation failed.");
            return;
        }
    }
    #make symlinks so existence checks pass later on
    unless(Genome::Utility::FileSystem->create_symlink("$build_directory/all_sequences.fa","$build_directory/all_sequences.bowtie")) {
        $self->error_message("Unable to symlink all_sequences.bowtie to all_sequences.fa");
        return;
    }

    unless(Genome::Utility::FileSystem->create_symlink("$build_directory/all_sequences.fa","$build_directory/all_sequences.bowtie.fa")) {
        $self->error_message("Unable to symlink all_sequences.bowtie.fa to all_sequences.fa");
        return;
    }

    #link in the samtools indexes
    unless(Genome::Utility::FileSystem->create_symlink("$build_directory/all_sequences.fa.fai","$build_directory/all_sequences.bowtie.fai")) {
        $self->error_message("Unable to symlink all_sequences.bowtie.fai to all_sequences.fa.fai");
        return;
    }

    unless(Genome::Utility::FileSystem->create_symlink("$build_directory/all_sequences.fa.fai","$build_directory/all_sequences.bowtie.fa.fai")) {
        $self->error_message("Unable to symlink all_sequences.bowtie.fa.fai to all_sequences.fa.fai");
        return;
    }

    $self->status_message("Done.");
    return 1;
}

# This function makes a .bases file for each chromosome in all_sequences.fa.  The code to do this by reading
# all_sequences.fa one line at a time would be a lot simpler, but there is no guarantee that a single line
# of sequence data is smaller than the amount of available memory.  Consequently, the fasta is read in
# chunks.
sub _make_bases_files {
    my $self = shift;
    my ($fasta_file_name, $output_directory) = @_;

    my $fasta_fh = Genome::Utility::FileSystem->open_file_for_reading($fasta_file_name);

    #Since a "\n<" in the middle of the file represents the start of a new chromosome,
    #add a newline to the start so the beginning of the file should look like "\n<", too.
    my $buffer = "\n";
    my $chunk_length = 1_048_576; #1 MiB
    my $current_chromosome_fh;

    while( $fasta_fh->read($buffer, $chunk_length, length($buffer)) ){
        $self->_process_buffer(\$buffer, \$current_chromosome_fh, $output_directory);
    }

    while( length($buffer) and $buffer ne "\n" ) {
        my $made_progress = $self->_process_buffer(\$buffer, \$current_chromosome_fh, $output_directory); #Finish up any remaining buffer after EOF
        unless($made_progress) {
            #We were expecting more data--file ended with an incomplete chromosome name line?
            $self->errror_message('Failed to process entire FASTA file into .bases file(s).');
            return;
        }
    }

    return 1;
}

sub _process_buffer {
    my $self = shift;
    my ($buffer_ref, $current_chromosome_fh_ref, $output_directory) = @_;

    if($$buffer_ref =~ /^\n>/) {
        #Start of a new chromsome
        my $break_index = index($$buffer_ref, "\n", 2); #find end of >chromosome name line
        unless($break_index) {
            return; #Don't have whole chromosome name line in buffer--need more
        }

        if($$current_chromosome_fh_ref) {
            close($$current_chromosome_fh_ref);
            undef $$current_chromosome_fh_ref;
        }

        my $name_line = substr($$buffer_ref, 0, $break_index, '');
        my $current_chromosome_name = $self->_parse_chromosome_name($name_line);
        if($current_chromosome_name) {
            my $current_chromosome_file_name = File::Spec->catfile($output_directory, $current_chromosome_name . '.bases');
            $self->error_message('Name: '.$current_chromosome_name.' from header line: '.$name_line.' is not unique, check parsing.') 
                if -e $current_chromosome_file_name;
            $$current_chromosome_fh_ref = Genome::Utility::FileSystem->open_file_for_writing($current_chromosome_file_name);
            $self->status_message('...Generating ' . $current_chromosome_name . '.bases');
        } else {
            #Skipping unknown chromosome--will be read past but not written to a .bases file
        }
    }

    my $data_to_write;
    my $index_of_next_chromosome_start = index($$buffer_ref, "\n>");
    if($index_of_next_chromosome_start > 0) {
        $data_to_write = substr($$buffer_ref, 0, $index_of_next_chromosome_start, '');
    } else {
        $data_to_write = $$buffer_ref;

        #If we're ending on a "\n", the first character we haven't seen might be a <
        #Act like we didn't look at the "\n" yet to be safe
        if(substr($$buffer_ref, -1, -1) eq "\n") {
            $$buffer_ref = "\n";
        } else {
            $$buffer_ref = '';
        }
    }

    $data_to_write =~ s/\n//g;
    if($$current_chromosome_fh_ref and length($data_to_write) > 0) {
        $$current_chromosome_fh_ref->print($data_to_write);
    }

    return 1;
}

sub _parse_chromosome_name {
    my $self = shift;
    my $name_line = shift;

    if ( $name_line =~ /^\n>\s*(\w+)\s*$/ ||
            $name_line =~ /^\n>\s*gi\|.*chromosome\s+([^[:space:][:punct:]]+)/i ||
            $name_line =~ /^\n>\s*(\S+)/ ) {
            #$name_line =~ /^\n>\s*([^[:space:][:punct:]]+).*$/ ) {
            #This line will mess up NT_xxxxx chromosomes
        my $chromosome_name = $1;
        return $chromosome_name;
    } else {
        if (length($name_line) > 1024) {
            $name_line = substr($name_line, 0, 1024);
            $name_line .= '...';
        }
        $self->warning_message("Failed to parse the chromosome name from: $name_line.");
        return;
    }
}

1;
