
package Genome::Model::Tools::Galaxy::GenerateToolXml;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Galaxy::GenerateToolXml {
    is  => 'Command',
    has => [
        class_name => {
            is  => 'String',
            doc => 'Input class name'
        },
        output => {
            is_optional => 1,
            is => 'String',
            doc => 'XML string'
        },
        'print' => {
            is => 'Boolean',
            doc => 'Prints XML to stdout by default',
            default_value => 1
        }
    ]
};

sub execute {
    my $self = shift;

    $DB::single=1;

    my $class_name = $self->class_name;
    {
        eval "use " . $self->class_name;
        if ($@) {
            die $@;
        }
    }

    my $class_meta = $class_name->get_class_object;
    if ( !$class_meta ) {
        $self->error_message("Invalid command class: $class_name");
        return 0;
    }

    my $help_brief  = $class_name->help_brief;
    my $help_detail;
    {
        local $ENV{ANSI_COLORS_DISABLED} = 1;
        $help_detail = $class_name->help_usage_complete_text;
    }

    my $tool_id = $class_name->command_name;
    $tool_id =~ s/ /_/g;

    my $tool_name = $class_name->command_name;
    my $command_line = $tool_name;
    my $input_params = '';
    my $output_data = '';

    $input_params = <<"    XML";
    <param name="command_line" type="text"/> 
    <param name="in_file" type="text" value="/dev/null"/>
    XML

    $output_data = <<"    XML";
    <data name="out_file" format="txt" label="$tool_name"/>
    XML

    # galaxy will bold headers surrounded by * like **THIS**
    $help_detail =~ s/^([A-Z]+[A-Z ]+:?)/**$1**\n/mg;

    my $xml = <<"    XML";
<tool id="$tool_id" name="$tool_name">
  <description>$help_brief</description>
  <command>
    $command_line
  </command>
  <inputs>
$input_params</inputs>
  <outputs>
$output_data</outputs>
  <help>
$help_detail
  </help>
</tool>
    XML

    print $xml if $self->print;

    $self->output($xml);
    return 1
}

sub bin_properties {
    my ($properties, %spec) = @_;
    
    my %output = map { $_ => [] } keys %spec;
    foreach my $p (@$properties) {
        my @matched = grep {
            $spec{$_}->($p)
        } keys %spec;
        
        for (@matched) {
            push @{ $output{$_} }, $p;
        }
    }

    return %output;
}

