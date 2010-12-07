package Genome::Model::Tools::Dacc;

use strict;
use warnings;

use Genome;

require File::Copy;
use Data::Dumper 'Dumper';
require File::Temp;
require IPC::Run;

class Genome::Model::Tools::Dacc {
    is  => 'Command',
    #is_abstract => 1,
    has => [
        sample_id => {
            is => 'Text',
            is_input => 1,
            shell_args_position => 1,
            doc => 'Sample id from the DACC.',
        },
        format => {
            is => 'Text',
            is_input => 1,
            shell_args_position => 2,
            valid_values => [ valid_formats() ],
            doc => 'Format of the SRA id to download.',
        },
        # config
        user => { value => 'jmartin', is_constant => 1, },
        site => { value => 'aspera.hmpdacc.org', is_constant => 1, },
        certificate => { value => '/gsc/scripts/share/certs/dacc/dacc.ppk', is_constant => 1, },
        ssh_key => { value => '/gsc/scripts/share/certs/dacc/dacc.sshkey', is_constant => 1, },
    ],
};

sub __display_name__ {
    return $_[0]->sample_id.' '.$_[0]->format;
}

sub help_brief {
    return 'Donwload from and upload to the DACC';
}

sub help_detail {
    return help_brief();
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    if ( not $self->sample_id ) {
        $self->error_message('No sampel id given.');
        return;
    }
    if ( $self->sample_id !~ /^SRS/ ) {
        $self->error_message('Sample id: '. $self->sample_id);
        return;
    }

    return $self;
}

sub formats_and_info {
    return (
        fastq => {
            directory => '/WholeMetagenomic/02-ScreenedReads/ProcessedForAssembly',
        },
        sff => {
            directory => '/WholeMetagenomic/02-ScreenedReads/ProcessedForAssembly',
        },
        bam => {
            directory => '/WholeMetagenomic/05-Analysis/ReadMappingToReference',
        },
        kegg => {
            directory => '/WholeMetagenomic/04-Annotation/ReadAnnotationProteinDBS/KEGG',
        },
    );
}

sub valid_formats {
    my %formats = formats_and_info();
    return sort { $a cmp $b} keys %formats;
}

sub base_dacc_directory {
    my $self = shift;
    my %formats = formats_and_info();
    return $formats{ $self->format }->{directory};
}

sub dacc_directory {
    my $self = shift;
    my $dir = $self->base_dacc_directory;
    return $dir.'/'.$self->sample_id;
}

sub dacc_remote_directory {
    my $self = shift;
    my $dir = $self->base_dacc_directory;
    return $self->user_and_site.':'.$self->dacc_directory.'/';
}

sub user_and_site {
    return $_[0]->user.'@'.$_[0]->site;
}

sub base_command {
    my $self = shift;
    return 'ascp -Q -l100M -i '.$self->certificate;
}

sub temp_dir {
    my $self = shift;

    return $self->{_temp_dir} if $self->{_temp_dir};

    $self->{_temp_dir} = File::Temp::tempdir(CLEANUP => 1);

    return $self->{_temp_dir};
}

sub temp_ssh_key {
    my $self = shift;

    return $self->{_temp_ssh_key} if $self->{_temp_ssh_key};

    my $ssh_key = $self->ssh_key;
    my $temp_dir = $self->temp_dir;
    my $temp_ssh_key = $temp_dir.'/dacc.sshkey';

    my $copy_ok = File::Copy::copy($ssh_key, $temp_ssh_key);
    if ( not $copy_ok or not -e $temp_ssh_key ) {
        Carp::confess('Failed to copy the ssh key to temp location.');
    }
    chmod 0400, $temp_ssh_key;

    $self->{_temp_ssh_key} = $temp_ssh_key;
    print "Temp ssh key: $temp_ssh_key\n";

    return $self->{_temp_ssh_key};
}

sub available_files {
    my $self = shift;

    my ($in, $out);
    my $user_and_site = $self->user_and_site;
    my $temp_ssh_key = $self->temp_ssh_key;
    my $harness = IPC::Run::harness([ 'ssh', '-i', $temp_ssh_key, $user_and_site ], \$in, \$out);
    $harness->pump until $out;

    $out = '';
    my $directory = $self->dacc_directory;
    $in = "ls -l $directory\n";
    $harness->pump until $out;

    my %files_and_sizes;
    for my $line ( split("\n", $out) ) {
        my @tokens = split(/\s+/, $line);
        next if not $tokens[8];
        $files_and_sizes{ $tokens[8] } = $tokens[4];
    }

    return \%files_and_sizes;
}

sub is_host_a_blade {
    my $self = shift;

    my $hostname = `hostname`;
    if ( not defined $hostname ) {
        $self->error_message('Cannot get hostname');
        return;
    }
    
    return $hostname =~ /blade/ ? 1 : 0;
}

sub rusage_for_download {
    return "-R 'rusage[internet_download_mbps=100]'";
}

sub rusage_for_upload {
     return "-R 'rusage[internet_upload_mbps=100,aspera_upload_mbps=100]'";
}

#< MOVE FILE >#
sub _move_file {
    my ($self, $file, $new_file) = @_;

    Carp::confess("Cannot move file b/c none given!") if not $file;
    Carp::confess("Cannot move $file b/c it does not exist!") if not -e $file;
    Carp::confess("Cannot move $file to $new_file b/c no new file was given!") if not $new_file;

    $self->status_message("Move $file to $new_file");

    my $size = -s $file;
    $self->status_message("Size: $size");

    my $move_ok = File::Copy::move($file, $new_file);
    if ( not $move_ok ) {
        $self->error_message("Failed to move $file to $new_file: $!");
        return;
    }

    if ( not -e $new_file ) {
        $self->error_message('Move succeeded, but archive path does not exist.');
        return;
    }

    if ( $size != -s $new_file ) {
        $self->error_message("Moved $file to $new_file but now file size is different.");
        return;
    }

    $self->status_message("Move...OK");

    return 1;
}
#<>#

1;

