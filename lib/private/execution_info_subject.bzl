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

"""ExecutionInfoSubject implementation."""

load(":dict_subject.bzl", "DictSubject")
load(":str_subject.bzl", "StrSubject")

def _execution_info_subject_new(info, *, meta):
    """Create a new `ExecutionInfoSubject`

    Method: ExecutionInfoSubject.new

    Args:
        info: ([`testing.ExecutionInfo`]) provider instance.
        meta: ([`ExpectMeta`]) of call chain information.

    Returns:
        `ExecutionInfoSubject` struct.
    """

    # buildifier: disable=uninitialized
    public = struct(
        # keep sorted start
        requirements = lambda *a, **k: _execution_info_subject_requirements(self, *a, **k),
        exec_group = lambda *a, **k: _execution_info_subject_exec_group(self, *a, **k),
        # keep sorted end
    )
    self = struct(
        actual = info,
        meta = meta,
    )
    return public

def _execution_info_subject_requirements(self):
    """Create a `DictSubject` for the requirements values.

    Method: ExecutionInfoSubject.requirements

    Args:
        self: implicitly added

    Returns:
        `DictSubject` of the requirements.
    """
    return DictSubject.new(
        self.actual.requirements,
        meta = self.meta.derive("requirements()"),
    )

def _execution_info_subject_exec_group(self):
    """Create a `StrSubject` for the `exec_group` value.

    Method: ExecutionInfoSubject.exec_group

    Args:
        self: implicitly added

    Returns:
        A [`StrSubject`] for the exec group.
    """
    return StrSubject.new(
        self.actual.exec_group,
        meta = self.meta.derive("exec_group()"),
    )

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
ExecutionInfoSubject = struct(
    new = _execution_info_subject_new,
)
