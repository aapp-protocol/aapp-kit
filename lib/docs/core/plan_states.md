# plan_states

## Tests
Run: `t/test-run plan_states`

- `t/core/plan_states.t::test_defaults_resolve_by_name` -> the five kit statuses resolve to their slugs by name
- `t/core/plan_states.t::test_status_line_shapes` -> a Status line resolves with either list marker, extra spacing, or trailing prose
- `t/core/plan_states.t::test_sections_in_rank_order` -> Under Review and Refining share one section; five statuses give four sections, the Incubator first
- `t/core/plan_states.t::test_custom_status_from_config` -> an `aapp.planState.<slug>` entry resolves and sorts into its rank
- `t/core/plan_states.t::test_override_by_slug_keeps_position` -> an entry for a kit slug replaces its heading and keeps its position
- `t/core/plan_states.t::test_malformed_entries_skipped` -> malformed entries are skipped with one warning each; the registry still resolves and a skipped entry resolves to nothing
- `t/core/plan_states.t::test_unrecognized_statuses` -> a retired glyph and an unknown status resolve to nothing, never a default
- `t/core/plan_states.t::test_status_slug_reads_the_header_line_only` -> `plan_status_slug` and `plan_status_text` read the header's Status line, never one in a fence or after the first `## `
- `t/core/plan_states.t::test_status_matched_by_name_whatever_the_glyph` -> a status is matched by its name whatever glyph precedes it; a plan without a Status line has no slug
- `t/core/plan_states.t::test_status_is_matches_any_given_slug` -> `plan_status_is` is true when the plan's slug is any of those given
- `t/core/plan_states.t::test_set_status_rewrites_the_header_line_only` -> `plan_set_status` rewrites the header's Status line only
- `t/core/plan_states.t::test_set_status_refuses_unknown_slug_or_missing_line` -> an unknown slug or a plan without a Status line is refused, the file unchanged
- `t/core/plan_states.t::test_accessors_follow_adopter_statuses` -> the accessors write and read adopter statuses from `aapp.planState.*`
