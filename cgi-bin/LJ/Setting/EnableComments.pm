package LJ::Setting::EnableComments;
use base 'LJ::Setting';
use strict;
use warnings;

sub should_render {
    my ($class, $u) = @_;

    return $u && !$u->is_identity ? 1 : 0;
}

sub helpurl {
    my ($class, $u) = @_;

    return "comment";
}

sub label {
    my $class = shift;

    return $class->ml('setting.enablecomments.label');
}

sub option {
    my ($class, $u, $errs, $args) = @_;
    my $key = $class->pkgkey;

    my $enablecomments;
    if ($class->get_arg($args, "enablecomments")) {
        $enablecomments = $class->get_arg($args, "enablecomments");
    } else {
        $enablecomments = $u->{opt_showtalklinks} eq "Y" ? $u->{opt_whocanreply} : "none";
    }

    my @options = (
        all => $class->ml('setting.enablecomments.option.select.all'),
        reg => $class->ml('setting.enablecomments.option.select.regusers'),
        friends => $u->is_community ? $class->ml('setting.enablecomments.option.select.members') : $class->ml('setting.enablecomments.option.select.friends'),
        none => $class->ml('setting.enablecomments.option.select.none'),
    );

    my $ret = "<label for='${key}enablecomments'>" . $class->ml('setting.enablecomments.option') . "</label> ";
    $ret .= LJ::html_select({
        name => "${key}enablecomments",
        id => "${key}enablecomments",
        selected => $enablecomments,
    }, @options);
    $ret .= "<p class='details'>";
    $ret .= $u->is_community ? $class->ml('setting.enablecomments.option.note.comm') : $class->ml('setting.enablecomments.option.note.self');
    $ret .= "</p>";

    return $ret;
}

sub save {
    my ($class, $u, $args) = @_;

    my $val = $class->get_arg($args, "enablecomments");
    my $showtalklinks = $val eq "none" ? "N" : "Y";
    my $whocanreply = $val eq "none" ? $u->{opt_whocanreply} : $val;

    LJ::update_user($u, { opt_showtalklinks => $showtalklinks, opt_whocanreply => $whocanreply });

    return 1;
}

1;
