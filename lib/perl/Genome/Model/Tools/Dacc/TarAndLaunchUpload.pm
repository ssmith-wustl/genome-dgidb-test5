package Genome::Model::Tools::Dacc::TarAndLaunchUpload;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
require File::Basename;

class Genome::Model::Tools::Dacc::TarAndLaunchUpload { 
    is => 'Genome::Model::Tools::Dacc',
    has => [
        files => {
            is => 'Text',
            is_many => 1,
            shell_args_position => 4,
            doc => 'Files to tar and zip.',
        },
        tar_file => {
            is => 'Bolean',
            shell_args_position => 3,
            doc => 'Tar file.',
        },
        #upload_log_file => { },
    ],
};

sub execute {
    my $self = shift;

    my $tar_file = $self->tar_file;
    $self->status_message("Tar file: $tar_file");
    if ( $tar_file !~ /\.tgz$/ and $tar_file !~ /\.tar\.gz/  ) {
        $self->error_message('Tar file must have .tar.gz or .tgz extension');
        return;
    }

    my $file_string = join(' ', $self->files);
    $self->status_message("Files: $file_string");
    for my $file ( $self->files ) {
        if ( not -e $file ) {
            $self->error_message("File to upload ($file) does not exist");
            return;
        }
    }

    my $cmd = "tar cvzf $tar_file $file_string";
    my $rv = eval { Genome::Utility::FileSystem->shellcmd(cmd => $cmd); };
    if ( not $rv ) {
        $self->error_message("Tar command failed: $cmd");
        return;
    }
    if ( not -e $tar_file ) {
        $self->error_message('Tar command succeeded, but no tar file was created');
        return;
    }
    $self->status_message("Tar-ing...OK");

    $self->status_message("Launch upload");
    my $rusage = Genome::Model::Tools::Dacc->rusage_for_upload;
    my $logging = '-u '.$ENV{USER}.'@genome.wustl.edu';
    $cmd = 'bsub -q long '.$logging.' '.$rusage.' gmt dacc upload --sample-id '.$self->sample_id.' --format '.$self->format.' --files '.$tar_file;
    $rv = eval { Genome::Utility::FileSystem->shellcmd(cmd => $cmd); };
    if ( not $rv ) {
        $self->error_message("Failed to launch upload, but tar file exists: $tar_file");
    }
    else {
        $self->status_message("Launch upload...OK");
    }

    return 1;
}

#my $dir="/gscmnt/gc2102/research/mmitreva/sabubuck/MBLASTX_KEGG_RESULTS/";
#my $out=$dir."$options{sample_id}".".tar.gz";
#`tar -cvzf $out $options{files}`;
#my $cmd = 'setenv ASPERA_SCP_PASS password; ascp -Q -l100M $out sabubuck@aspera.hmpdacc.org:/WholeMetagenomic/04-Annotation/ReadAnnotationProteinDBS/KEGG/';
#system ($cmd);

1;

=pod

=head1 Name

ModuleTemplate

=head1 Synopsis

=head1 Usage

=head1 Methods

=head2 

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2009 Genome Center at Washington University in St. Louis

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

