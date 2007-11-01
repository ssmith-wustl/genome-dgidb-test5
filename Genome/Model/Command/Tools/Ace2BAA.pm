package Genome::Model::Command::Tools::Ace2BAA;

use strict;
use warnings;

use above "Genome";
use Command;
use File::Path;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [                                # Specify the command's properties (parameters) <--- 
        'sample'   => { type => 'String',  doc => "sample name"},
        'dir'   => { type => 'String',  doc => "Polybayes alignment (output) directory"},
        'bindir'   => { type => 'String',  doc => "directory for binary executables for polybayes", is_optional => 1}
    ], 
);

sub help_brief {
    "convert a (consed) Ace file to BAA (polybayes) format"
}

sub execute {
    my $self = shift;
		my($sample, $dir, $bindir) = 
				 ($self->sample, $self->dir, $self->bindir);
		$bindir ||= '/gscmnt/sata114/info/medseq/pkg/bin64';
		return unless ( defined($sample) && defined($dir)
									);
		my $ace2baa ||= "$bindir/ace2Baa";

		$dir =~ s/ \/ $ //x;					# Remove any trailing slash

		# Make sure the output directory exists
		unless (-e $dir) {
			mkpath $dir;
		}

		system("cd $dir ; $ace2baa --ace edit_dir/$sample.ace --baa $sample.baa");
}

1;


