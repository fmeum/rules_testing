# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""CollectionSubject implementation."""

load(
    ":check_util.bzl",
    "check_contains_at_least_predicates",
    "check_contains_exactly",
    "check_contains_exactly_predicates",
    "check_contains_none_of",
    "check_contains_predicate",
    "check_not_contains_predicate",
)
load(
    ":failure_messages.bzl",
    "format_actual_collection",
    "format_problem_expected_exactly",
    "format_problem_matched_out_of_order",
    "format_problem_missing_required_values",
    "format_problem_predicates_did_not_match",
    "format_problem_unexpected_values",
)
load(":int_subject.bzl", "IntSubject")
load(":matching.bzl", "matching")
load(":truth_common.bzl", "to_list")

def _collection_subject_new(
        values,
        meta,
        container_name = "values",
        sortable = True,
        element_plural_name = "elements"):
    """Creates a "CollectionSubject" struct.

    Method: CollectionSubject.new

    Public Attributes:
    * `actual`: The wrapped collection.

    Args:
        values: ([`collection`]) the values to assert against.
        meta: ([`ExpectMeta`]) the metadata about the call chain.
        container_name: ([`str`]) conceptual name of the container.
        sortable: ([`bool`]) True if output should be sorted for display, False if not.
        element_plural_name: ([`str`]) the plural word for the values in the container.

    Returns:
        [`CollectionSubject`].
    """

    # buildifier: disable=uninitialized
    public = struct(
        # keep sorted start
        actual = values,
        has_size = lambda *a, **k: _collection_subject_has_size(self, *a, **k),
        contains = lambda *a, **k: _collection_subject_contains(self, *a, **k),
        contains_at_least = lambda *a, **k: _collection_subject_contains_at_least(self, *a, **k),
        contains_at_least_predicates = lambda *a, **k: _collection_subject_contains_at_least_predicates(self, *a, **k),
        contains_exactly = lambda *a, **k: _collection_subject_contains_exactly(self, *a, **k),
        contains_exactly_predicates = lambda *a, **k: _collection_subject_contains_exactly_predicates(self, *a, **k),
        contains_none_of = lambda *a, **k: _collection_subject_contains_none_of(self, *a, **k),
        contains_predicate = lambda *a, **k: _collection_subject_contains_predicate(self, *a, **k),
        not_contains_predicate = lambda *a, **k: _collection_subject_not_contains_predicate(self, *a, **k),
        # keep sorted end
    )
    self = struct(
        actual = values,
        meta = meta,
        element_plural_name = element_plural_name,
        container_name = container_name,
        sortable = sortable,
        contains_predicate = public.contains_predicate,
        contains_at_least_predicates = public.contains_at_least_predicates,
    )
    return public

def _collection_subject_has_size(self, expected):
    """Asserts that `expected` is the size of the collection.

    Method: CollectionSubject.has_size

    Args:
        self: implicitly added.
        expected: ([`int`]) the expected size of the collection.
    """
    return IntSubject.new(
        len(self.actual),
        meta = self.meta.derive("size()"),
    ).equals(expected)

def _collection_subject_contains(self, expected):
    """Asserts that `expected` is within the collection.

    Method: CollectionSubject.contains

    Args:
        self: implicitly added.
        expected: ([`str`]) the value that must be present.
    """
    matcher = matching.equals_wrapper(expected)
    return self.contains_predicate(matcher)

def _collection_subject_contains_exactly(self, expected):
    """Check that a collection contains exactly the given elements.

    Method: CollectionSubject.contains_exactly

    * Multiplicity is respected.
    * The collection must contain all the values, no more or less.
    * Checking that the order of matches is the same as the passed-in matchers
      order can be done by call `in_order()`.

    The collection must contain all the values and no more. Multiplicity of
    values is respected. Checking that the order of matches is the same as the
    passed-in matchers order can done by calling `in_order()`.

    Args:
        self: implicitly added.
        expected: ([`list`]) values that must exist.
    Returns
        [`Ordered`] (see `_ordered_incorrectly_new`).
    """
    expected = to_list(expected)
    return check_contains_exactly(
        actual_container = self.actual,
        expect_contains = expected,
        meta = self.meta,
        format_actual = lambda: format_actual_collection(
            self.actual,
            name = self.container_name,
            sort = False,  # Don't sort; this might be rendered by the in_order() error.
        ),
        format_expected = lambda: format_problem_expected_exactly(
            expected,
            sort = False,  # Don't sort; this might be rendered by the in_order() error.
        ),
        format_missing = lambda missing: format_problem_missing_required_values(
            missing,
            sort = self.sortable,
        ),
        format_unexpected = lambda unexpected: format_problem_unexpected_values(
            unexpected,
            sort = self.sortable,
        ),
        format_out_of_order = format_problem_matched_out_of_order,
    )

def _collection_subject_contains_exactly_predicates(self, expected):
    """Check that the values correspond 1:1 to the predicates.

    Method: CollectionSubject.contains_exactly_predicates

    * There must be a 1:1 correspondence between the container values and the
      predicates.
    * Multiplicity is respected (i.e., if the same predicate occurs twice, then
      two distinct elements must match).
    * Matching occurs in first-seen order. That is, a predicate will "consume"
      the first value in `actual_container` it matches.
    * The collection must match all the predicates, no more or less.
    * Checking that the order of matches is the same as the passed-in matchers
      order can be done by call `in_order()`.

    Note that confusing results may occur if predicates with overlapping
    match conditions are used. For example, given:
      actual=["a", "ab", "abc"],
      predicates=[<contains a>, <contains b>, <equals a>]

    Then the result will be they aren't equal: the first two predicates
    consume "a" and "ab", leaving only "abc" for the <equals a> predicate
    to match against, which fails.

    Args:
        self: implicitly added.
        expected: ([`list`] of [`Matcher`]) that must match.
    Returns
        [`Ordered`] (see `_ordered_incorrectly_new`).
    """
    expected = to_list(expected)
    return check_contains_exactly_predicates(
        actual_container = self.actual,
        expect_contains = expected,
        meta = self.meta,
        format_actual = lambda: format_actual_collection(
            self.actual,
            name = self.container_name,
            sort = False,  # Don't sort; this might be rendered by the in_order() error.
        ),
        format_expected = lambda: format_problem_expected_exactly(
            [e.desc for e in expected],
            sort = False,  # Don't sort; this might be rendered by the in_order() error.
        ),
        format_missing = lambda missing: format_problem_missing_required_values(
            [m.desc for m in missing],
            sort = self.sortable,
        ),
        format_unexpected = lambda unexpected: format_problem_unexpected_values(
            unexpected,
            sort = self.sortable,
        ),
        format_out_of_order = format_problem_matched_out_of_order,
    )

def _collection_subject_contains_none_of(self, values):
    """Asserts the collection contains none of `values`.

    Method: CollectionSubject.contains_none_of

    Args:
        self: implicitly added
        values: ([`collection`]) values of which none of are allowed to exist.
    """
    check_contains_none_of(
        collection = self.actual,
        none_of = values,
        meta = self.meta,
        sort = self.sortable,
    )

def _collection_subject_contains_predicate(self, matcher):
    """Asserts that `matcher` matches at least one value.

    Method: CollectionSubject.contains_predicate

    Args:
        self: implicitly added.
        matcher: ([`Matcher`]) (see `matchers` struct).
    """
    check_contains_predicate(
        self.actual,
        matcher = matcher,
        format_problem = "expected to contain: {}".format(matcher.desc),
        format_actual = lambda: format_actual_collection(
            self.actual,
            name = self.container_name,
            sort = self.sortable,
        ),
        meta = self.meta,
    )

def _collection_subject_contains_at_least(self, expect_contains):
    """Assert that the collection is a subset of the given predicates.

    Method: CollectionSubject.contains_at_least

    The collection must contain all the values. It can contain extra elements.
    The multiplicity of values is respected. Checking that the relative order
    of matches is the same as the passed-in expected values order can done by
    calling `in_order()`.

    Args:
        self: implicitly added.
        expect_contains: ([`list`]) values that must be in the collection.

    Returns:
        [`Ordered`] (see `_ordered_incorrectly_new`).
    """
    matchers = [
        matching.equals_wrapper(expected)
        for expected in to_list(expect_contains)
    ]
    return self.contains_at_least_predicates(matchers)

def _collection_subject_contains_at_least_predicates(self, matchers):
    """Assert that the collection is a subset of the given predicates.

    Method: CollectionSubject.contains_at_least_predicates

    The collection must match all the predicates. It can contain extra elements.
    The multiplicity of matchers is respected. Checking that the relative order
    of matches is the same as the passed-in matchers order can done by calling
    `in_order()`.

    Args:
        self: implicitly added.
        matchers: ([`list`] of [`Matcher`]) (see `matchers` struct).

    Returns:
        [`Ordered`] (see `_ordered_incorrectly_new`).
    """
    ordered = check_contains_at_least_predicates(
        self.actual,
        matchers,
        format_missing = lambda missing: format_problem_predicates_did_not_match(
            missing,
            element_plural_name = self.element_plural_name,
            container_name = self.container_name,
        ),
        format_out_of_order = format_problem_matched_out_of_order,
        format_actual = lambda: format_actual_collection(
            self.actual,
            name = self.container_name,
            sort = self.sortable,
        ),
        meta = self.meta,
    )
    return ordered

def _collection_subject_not_contains_predicate(self, matcher):
    """Asserts that `matcher` matches no values in the collection.

    Method: CollectionSubject.not_contains_predicate

    Args:
        self: implicitly added.
        matcher: [`Matcher`] object (see `matchers` struct).
    """
    check_not_contains_predicate(
        self.actual,
        matcher = matcher,
        meta = self.meta,
        sort = self.sortable,
    )

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
CollectionSubject = struct(
    new = _collection_subject_new,
)
