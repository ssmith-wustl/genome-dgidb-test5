
package Genome::Model::Tools::Galaxy::Update;

use strict;
use warnings;
use Genome;
use File::Copy;

class Genome::Model::Tools::Galaxy::Update {
    is  => 'Command',
    has => [
        path => {
            is  => 'String',
            is_optional => 1,
            doc => 'Galaxy setup path'
        },
        pull => {
            is => 'Boolean',
            is_optional => 1,
            doc => 'Update Galaxy software',
            default => 0
        }
    ]
};

sub execute {
    my $self = shift;

    my $path = $self->path;
    if (!defined($path)) {
        $path = $ENV{HOME} . "/galaxy/";
    }

    # look for key files to make sure path is galaxy directory
    my @key_files = (".hg", "run_galaxy_listener.sh", "run.sh");
    foreach my $k (@key_files) {
        my $file_path = $path . "/" . $k;
        unless (-e $file_path) {
            $self->warning_message("Does not appear to be valid galaxy folder");
            die();
        }
    }

    if ($self->pull) {
        chdir($path);
        system('hg pull -u');
        # check pull -u had 0 exit code
        unless ($? == 0) {
            $self->warning_message("Error occured in pulling updated Galaxy from mercurial source.");
            die();
        }
    }

    # FIXME Because of ur test use fails, only searching Genome::Model::Tools::Music subcommands 
    my @xml_files = ();
    my @gmt_tools = Genome::Model::Tools::Music->sorted_sub_command_classes;
    foreach my $c (@gmt_tools) {
        push(@gmt_tools, $c->sorted_sub_command_classes);
        $c =~ s/::/\//g;
        $c .= '.pm';
        require $c;
        my $galaxy_xml_path = $INC{$c} . ".galaxy.xml";
        # if Module.pm.galaxy.xml file exists we will move it into tools directory
        if (-e $galaxy_xml_path) {
            push(@xml_files, $galaxy_xml_path);
        }
    }
    mkdir("$path/tools/genome");
    foreach my $xml_file (@xml_files) {
        (my $fn) = ($xml_file =~ /\/(\w+).pm.galaxy.xml/);
        copy($xml_file, "$path/tools/genome/$fn.xml");
    }
    # handle tool_conf.xml rewrite
    # read tool_conf.xml
    open(tool_conf_ifh, '<', "$path/tool_conf.xml");
    print "$path/tool_conf.xml" . "\n";
    my $tool_xml = '';
    while (<tool_conf_ifh>) {
        $tool_xml .= $_;
    }
    close(tool_conf_ifh);
    # Either replace existing Genome section or put it right after toolbox tag
    my $new_genome_section = '<section name="Genome" id="genome">' . "\n";
    foreach my $tool (@xml_files) {
        (my $fn) = ($tool =~ /\/(\w+).pm.galaxy.xml/);
        $new_genome_section .= '    <tool file="genome/' . $fn . '.xml" />' . "\n"; 
    }
    $new_genome_section .= "</section>\n";
    print $new_genome_section . "\n";
    unless ($tool_xml =~ s/^\s+<section name="Genome" id="genome">.*?<\/section>\n/$new_genome_section/ms) {
        $tool_xml =~ s/^<toolbox>\n/<toolbox>\n$new_genome_section/ms;
    }
    print $tool_xml;
    # write tool_conf.xml
    open(tool_conf_ofh, '>', "$path/tool_conf.xml");
    print tool_conf_ofh $tool_xml;
    close(tool_conf_ofh);
}
