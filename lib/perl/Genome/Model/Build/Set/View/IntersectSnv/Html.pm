package Genome::Model::Build::Set::View::IntersectSnv::Html;

use strict;
use warnings;

use File::Basename;
use Data::Dumper;
use Genome;
use JSON;
use Sort::Naturally;
use Template;

class Genome::Model::Build::Set::View::IntersectSnv::Html {
    is => 'UR::Object::View::Default::Html',
    has_constant => [
        perspective => {
            value => 'intersect',
        },
    ],
};

sub build_detail_html {
    my ($self, @builds) = @_;

    my $html = "<center><table class=\"build_detail\">\n";
    $html .= "<tr><th colspan=\"4\">Build Detail</th></tr>\n";
    $html .= "<tr><th>Id</th><th>Type</th><th>Model Id</th><th>Model Name</th></tr>\n";
    for my $b (@builds) {
        my $id= $b->id;
        my $type = $b->type_name;
        my $model_id = $b->model->id;
        my $model_name = $b->model->__display_name__;
        $model_name = substr($model_name, 0, 50)."..." if length($model_name) > 50;
        $html .= "<tr><td>$id</td><td>$type</td><td>$model_id</td><td>$model_name</td></tr>\n";
    }
    $html .= "</table></center>\n";
    return $html;
}

sub _generate_content {
    my $self = shift;

    my $ids = $self->subject->id;
    $ids = [$ids] if !ref $ids;
    if (@$ids != 2) {
        return $self->_format_error("Error: expected 2 build ids but got ". (scalar @$ids) .", [". join(',', @$ids) ."]");
    }

    my @builds = map {Genome::Model::Build->get($_)} @$ids;
    my %filter_methods = (
        filtered => "filtered_snvs_bed",
        unfiltered => "snvs_bed"
    );
    my @unfiltered_files = map {$_->snvs_bed("v1")} @builds;
    my @filtered_files = map {$_->filtered_snvs_bed("v1")} @builds;
    my @names = map {$_->id} @builds;
    my $title = "Snv Intersection for builds: " . join(", ", @names);

    my $report = $self->build_detail_html(@builds);
    for my $filt ( keys %filter_methods ) {
        my $fn = $filter_methods{$filt};
        my @files = map { $_->$fn("v1") } @builds;
        my $tmpfile = Genome::Sys->create_temp_file_path;
        my $cmd = Genome::Model::Tools::Joinx::SnvConcordance->create(
            input_file_a => $files[0],
            input_file_b => $files[1],
            output_file => $tmpfile,
        );
        eval { $cmd->execute; };
        if ($@) { return $self->_format_error($@); }
        my $results = Genome::Model::Tools::Joinx::SnvConcordance::parse_results_file($tmpfile);

        my @errs = $cmd->__errors__;
        if (@errs) {
            return $self->_format_error(join ("\n", map{$_->__display_name__} @errs));
        }
        $report .= format_results_html($results, ucfirst($filt)." SNVs");
    }

    return $self->_render_view($title, $report);
}

sub format_results_html {
    my ($results, $title) = @_;

    my $html = "<div class=\"section_content\">\n";
    $html .= "<h2 class=\"section_title\">$title</h2><br>\n";
    $html .= "<div style=\"padding-left: 10px;\">\n";
    $html .= "<table class=\"snv\">\n";
    for my $a_type (keys %$results) {
        next if scalar keys %{$results->{$a_type}{hits}} == 0;
        my $total = $results->{$a_type}{total}; 
        my $uc_a_type = join(" ", map { ucfirst($_) } split(" ", $a_type));
        $html .= "<tr><td class=\"snv_category_head\">$uc_a_type</td>\n";
        $html .= "<td class=\"snv_category_head\" colspan=\"3\">$total</td></tr>\n";
        $html .= "<tr class=\"snv_category_flds\">\n";
        $html .= "<th>&nbsp;</td>\n";
        $html .= "<th>SNVs</td>\n";
        $html .= "<th>%</td>\n";
        $html .= "<th>Avg Qual</td>\n";
        $html .= "</tr>\n";
        for my $match_type (keys %{$results->{$a_type}{hits}}) {
            my $uc_match_type = join(" ", map { ucfirst($_) } split(" ", $match_type));
            $html .= "<tr><td class=\"match_type\" colspan=\"4\">$uc_match_type</td></tr>\n";
            for my $b_type (keys %{$results->{$a_type}{hits}{$match_type}}) {
                $html .= "<tr>\n";
                my $count = $results->{$a_type}{hits}{$match_type}{$b_type}{count};
                my $qual  = $results->{$a_type}{hits}{$match_type}{$b_type}{qual};
                my $percent = sprintf "%.02f", 100*$count / $total; 
                $html .= "<td class=\"hit_detail\">$b_type</td>\n";
                $html .= "<td class=\"hit_detail\">$count</td>\n";
                $html .= "<td class=\"hit_detail\">$percent</td>\n";
                $html .= "<td class=\"hit_detail\">$qual</td>\n";
                $html .= "</tr>\n";
            }
        }
    }
    $html .= "</table></div></div>\n";
     
    return $html;
}

sub _format_error {
    my ($self, $message) = @_;
    $message = "<div class=\"error\">$message</div>";
    return $self->_render_view("Error", $message);
}

sub _get_results {
    my ($self, $build) = @_;
}

sub _base_path_for_templates {
    my $module = __PACKAGE__;
    $module =~ s/::/\//g;
    $module .= '.pm';
    my $module_path = $INC{$module};
    unless ($module_path) {
        die "Module " . __PACKAGE__ . " failed to find its own path!  Checked for $module in \%INC...";
    }
    return dirname($module_path);
}

sub _support_file_path {
    my ($self, $file) = @_;
    return $self->_base_path_for_templates . "/$file";
}

sub _hashref_to_json_array {
    my ($h) = @_;

    my @arr = map { [$_, $h->{$_}] } sort {$a <=> $b} keys %$h;

    return to_json(\@arr, {ascii => 1});
}

sub _render_view {
    my ($self, $title, $report_html) = @_;

    ## get CSS resources
    my $css_file = $self->_support_file_path("Intersect.css");
    my $css_fh = IO::File->new($css_file);
    unless ($css_fh) {
        die "failed to open file $css_file!"; 
    }
    my $page_css = join('',$css_fh->getlines);

    my @vars = (
        page_title => $title,
        style => $page_css,
        report_content => $report_html,
    );

    my $template = $self->_support_file_path("Intersect.html.tt2");
    my $tt = Template->new({ ABSOLUTE => 1 }) || die "$Template::ERROR\n";

    $self->status_message("processing template $template");

    my $content;
    my $rv = $tt->process($template, { @vars }, \$content) || die $tt->error(), "\n";
    if ($rv != 1) {
   	    die "Bad return value from template processing for summary report generation: $rv ";
    }
    unless ($content) {
        die "No content returned from template processing!";
    }
    return $content;
}

sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}

1;
