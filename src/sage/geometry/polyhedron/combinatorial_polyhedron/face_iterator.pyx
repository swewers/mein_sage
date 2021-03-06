# distutils: depends = sage/geometry/polyhedron/combinatorial_polyhedron/bit_vector_operations.cc
# distutils: language = c++
# distutils: extra_compile_args = -std=c++11

r"""
Face iterator for polyhedra

This iterator in principle works on every graded lattice, where
every interval of length two has exactly 4 elements (diamond property).

It also works on unbounded polyhedra, as those satisfy the diamond property,
except for intervals including the empty face.
A (slightly generalized) description of the algorithm can be found in [KS2019]_.

Terminology in this module:

- Coatoms               -- the faces from which all others are constructed in
                           the face iterator. This will be facets or Vrep.
                           In non-dual mode, faces are constructed as
                           intersections of the facets. In dual mode, the are
                           constructed theoretically as joins of vertices.
                           The coatoms are repsented as incidences with the
                           atoms they contain.
- Atoms                 -- facets or Vrep depending on application of algorithm.
                           Atoms are repsented as incidences of coatoms they
                           are contained in.

.. SEEALSO::

    :mod:`sage.geometry.polyhedron.combinatorial_polyhedron.base`.

EXAMPLES:

Construct a face iterator::

    sage: from sage.geometry.polyhedron.combinatorial_polyhedron.face_iterator \
    ....:         import FaceIterator
    sage: P = polytopes.octahedron()
    sage: C = CombinatorialPolyhedron(P)

    sage: FaceIterator(C, False)
    Iterator over the proper faces of a 3-dimensional combinatorial polyhedron
    sage: FaceIterator(C, False, output_dimension=2)
    Iterator over the 2-faces of a 3-dimensional combinatorial polyhedron

Iterator in the non-dual mode starts with facets::

    sage: it = FaceIterator(C, False)
    sage: [next(it) for _ in range(9)]
    [A 2-dimensional face of a 3-dimensional combinatorial polyhedron,
     A 2-dimensional face of a 3-dimensional combinatorial polyhedron,
     A 2-dimensional face of a 3-dimensional combinatorial polyhedron,
     A 2-dimensional face of a 3-dimensional combinatorial polyhedron,
     A 2-dimensional face of a 3-dimensional combinatorial polyhedron,
     A 2-dimensional face of a 3-dimensional combinatorial polyhedron,
     A 2-dimensional face of a 3-dimensional combinatorial polyhedron,
     A 2-dimensional face of a 3-dimensional combinatorial polyhedron,
     A 1-dimensional face of a 3-dimensional combinatorial polyhedron]

Iterator in the dual-mode starts with vertices::

    sage: it = FaceIterator(C, True)
    sage: [next(it) for _ in range(7)]
    [A 0-dimensional face of a 3-dimensional combinatorial polyhedron,
     A 0-dimensional face of a 3-dimensional combinatorial polyhedron,
     A 0-dimensional face of a 3-dimensional combinatorial polyhedron,
     A 0-dimensional face of a 3-dimensional combinatorial polyhedron,
     A 0-dimensional face of a 3-dimensional combinatorial polyhedron,
     A 0-dimensional face of a 3-dimensional combinatorial polyhedron,
     A 1-dimensional face of a 3-dimensional combinatorial polyhedron]

Obtain the Vrepresentation::

    sage: it = FaceIterator(C, False)
    sage: face = next(it)
    sage: face.ambient_Vrepresentation()
    (A vertex at (0, -1, 0), A vertex at (0, 0, -1), A vertex at (1, 0, 0))
    sage: face.n_ambient_Vrepresentation()
    3

Obtain the facet-representation::

    sage: it = FaceIterator(C, True)
    sage: face = next(it)
    sage: face.ambient_Hrepresentation()
    (An inequality (-1, -1, 1) x + 1 >= 0,
     An inequality (-1, -1, -1) x + 1 >= 0,
      An inequality (-1, 1, -1) x + 1 >= 0,
       An inequality (-1, 1, 1) x + 1 >= 0)
    sage: face.ambient_H_indices()
    (4, 5, 6, 7)
    sage: face.n_ambient_Hrepresentation()
    4

In non-dual mode one can ignore all faces contained in the current face::

    sage: it = FaceIterator(C, False)
    sage: face = next(it)
    sage: face.ambient_H_indices()
    (7,)
    sage: it.ignore_subfaces()
    sage: [face.ambient_H_indices() for face in it]
    [(6,),
    (5,),
    (4,),
    (3,),
    (2,),
    (1,),
    (0,),
    (5, 6),
    (1, 6),
    (0, 1, 5, 6),
    (4, 5),
    (0, 5),
    (0, 3, 4, 5),
    (3, 4),
    (2, 3),
    (0, 3),
    (0, 1, 2, 3),
    (1, 2),
    (0, 1)]

In dual mode one can ignore all faces that contain the current face::

    sage: it = FaceIterator(C, True)
    sage: face = next(it)
    sage: face.ambient_V_indices()
    (5,)
    sage: it.ignore_supfaces()
    sage: [face.ambient_V_indices() for face in it]
    [(4,),
    (3,),
    (2,),
    (1,),
    (0,),
    (3, 4),
    (2, 4),
    (0, 4),
    (0, 3, 4),
    (0, 2, 4),
    (1, 3),
    (0, 3),
    (0, 1, 3),
    (1, 2),
    (0, 2),
    (0, 1, 2),
    (0, 1)]

There is a special face iterator class for geometric polyhedra.
It yields (geometric) polyhedral faces and it also yields trivial faces.
Otherwise, it works exactly the same::

    sage: from sage.geometry.polyhedron.combinatorial_polyhedron.face_iterator \
    ....:         import FaceIterator_geom
    sage: P = polytopes.cube()
    sage: it = FaceIterator_geom(P)
    sage: [next(it) for _ in range(5)]
    [A 3-dimensional face of a Polyhedron in ZZ^3 defined as the convex hull of 8 vertices,
     A -1-dimensional face of a Polyhedron in ZZ^3,
     A 2-dimensional face of a Polyhedron in ZZ^3 defined as the convex hull of 4 vertices,
     A 2-dimensional face of a Polyhedron in ZZ^3 defined as the convex hull of 4 vertices,
     A 2-dimensional face of a Polyhedron in ZZ^3 defined as the convex hull of 4 vertices]
    sage: it
    Iterator over the faces of a 3-dimensional polyhedron in ZZ^3

AUTHOR:

- Jonathan Kliem (2019-04)
"""

#*****************************************************************************
#       Copyright (C) 2019 Jonathan Kliem <jonathan.kliem@fu-berlin.de>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#                  http://www.gnu.org/licenses/
#*****************************************************************************

from sage.rings.integer     cimport smallInteger
from cysignals.signals      cimport sig_check, sig_on, sig_off
from .conversions           cimport bit_rep_to_Vrep_list
from .base                  cimport CombinatorialPolyhedron
from sage.geometry.polyhedron.face import combinatorial_face_to_polyhedral_face, PolyhedronFace

cdef extern from "bit_vector_operations.cc":
    cdef size_t get_next_level(
        uint64_t **faces, const size_t n_faces, uint64_t **nextfaces,
        uint64_t **nextfaces2, uint64_t **visited_all,
        size_t n_visited_all, size_t face_length) nogil
#        Set ``newfaces`` to be the facets of ``faces[n_faces -1]``
#        that are not contained in a face of ``visited_all``.

#        INPUT:

#        - ``maybe_newfaces`` -- quasi of type ``uint64_t[n_faces -1][face_length]``,
#          needs to be ``chunksize``-Bit aligned
#        - ``newfaces`` -- quasi of type ``*uint64_t[n_faces -1]
#        - ``visited_all`` -- quasi of type ``*uint64_t[n_visited_all]
#        - ``face_length`` -- length of the faces

#        OUTPUT:

#        - return number of ``newfaces``
#        - set ``newfaces`` to point to the new faces

#        ALGORITHM:

#        To get all facets of ``faces[n_faces-1]``, we would have to:
#        - Intersect the first ``n_faces-1`` faces of ``faces`` with the last face.
#        - Add all the intersection of ``visited_all`` with the last face
#        - Out of both the inclusion-maximal ones are of codimension 1, i.e. facets.

#        As we have visited all faces of ``visited_all``, we alter the algorithm
#        to not revisit:
#        Step 1: Intersect the first ``n_faces-1`` faces of ``faces`` with the last face.
#        Step 2: Out of thosse the inclusion-maximal ones are some of the facets.
#                At least we obtain all of those, that we have not already visited.
#                Maybe, we get some more.
#        Step 3: Only keep those that we have not already visited.
#                We obtain exactly the facets of ``faces[n_faces-1]`` that we have
#                not visited yet.

    cdef size_t count_atoms(uint64_t *A, size_t face_length) nogil
#        Return the number of atoms/vertices in A.
#        This is the number of set bits in A.
#        ``face_length`` is the length of A in terms of uint64_t.

    cdef size_t bit_rep_to_coatom_rep(
            uint64_t *face, uint64_t **coatoms, size_t n_coatoms,
            size_t face_length, size_t *output) nogil
#        Write the coatom-representation of face in output. Return length.
#        ``face_length`` is the length of ``face`` and ``coatoms[i]``
#        in terms of uint64_t.
#        ``n_coatoms`` length of ``coatoms``.

cdef extern from "Python.h":
    int unlikely(int) nogil  # Defined by Cython

cdef class FaceIterator_base(SageObject):
    r"""
    A base class to iterate over all faces of a polyhedron.

    Construct all proper faces from the facets. In dual mode, construct all proper
    faces from the vertices. Dual will be faster for less vertices than facets.

    See :class:`FaceIterator`.
    """
    def __init__(self, CombinatorialPolyhedron C, bint dual, output_dimension=None):
        r"""
        Initialize :class:`FaceIterator_base`.

        See :class:`FaceIterator_base`.

        EXAMPLES::

            sage: P = polytopes.permutahedron(4)
            sage: C = CombinatorialPolyhedron(P)
            sage: it = C.face_iter() # indirect doctest

            sage: f_vector = [1, 0, 0, 0, 1]
            sage: for face in it: f_vector[face.dimension()+1] += 1
            sage: print ('f_vector of permutahedron(4): ', f_vector)
            f_vector of permutahedron(4):  [1, 24, 36, 14, 1]

            sage: TestSuite(sage.geometry.polyhedron.combinatorial_polyhedron.face_iterator.FaceIterator).run()
        """
        if dual and not C.is_bounded():
            raise ValueError("cannot iterate over dual of unbounded Polyedron")
        cdef int i
        cdef ListOfFaces some_list  # make Cython aware of type

        self.dual = dual
        self.structure.dual = dual
        self.structure.face = NULL
        self.structure.dimension = C.dimension()
        self.structure.current_dimension = self.structure.dimension -1
        self._mem = MemoryAllocator()

        # We will not yield the empty face.
        # If there are `n` lines, than there
        # are no faces below dimension `n`.
        # The dimension of the level-sets in the face lattice jumps from `n` to `-1`.
        self.structure.lowest_dimension = 0

        if output_dimension is not None:
            if not output_dimension in range(0,self.structure.dimension):
                raise ValueError("``output_dimension`` must be the dimension of proper faces")
            if self.dual:
                # In dual mode, the dimensions are reversed.
                self.structure.output_dimension = self.structure.dimension - 1 - output_dimension
            else:
                self.structure.output_dimension = output_dimension
            self.structure.lowest_dimension = max(0, self.structure.output_dimension)
        else:
            self.structure.output_dimension = -2

        if dual:
            self.atoms = C.bitrep_facets()
            self.coatoms = C.bitrep_Vrep()
        else:
            self.coatoms = C.bitrep_facets()
            self.atoms = C.bitrep_Vrep()
        self.structure.face_length = self.coatoms.face_length
        self._Vrep = C.Vrep()
        self._facet_names = C.facet_names()
        self._equalities = C.equalities()
        self._bounded = C.is_bounded()

        self.structure.atom_rep = <size_t *> self._mem.allocarray(self.coatoms.n_atoms, sizeof(size_t))
        self.structure.coatom_rep = <size_t *> self._mem.allocarray(self.coatoms.n_faces, sizeof(size_t))

        if self.structure.dimension == 0 or self.coatoms.n_faces == 0:
            # As we will only yield proper faces,
            # there is nothing to yield in those cases.
            # We have to discontinue initialization,
            # as it assumes ``self.dimension > 0`` and ``self.n_faces > 0``.
            self.structure.current_dimension = self.structure.dimension
            return
        # We may assume ``dimension > 0`` and ``n_faces > 0``.

        # Initialize ``maybe_newfaces``,
        # the place where the new faces are being stored.
        self.newfaces_lists = tuple(ListOfFaces(self.coatoms.n_faces, self.coatoms.n_atoms)
                                    for i in range(self.structure.dimension -1))
        self.structure.maybe_newfaces = <uint64_t ***> self._mem.allocarray((self.structure.dimension -1), sizeof(uint64_t **))
        for i in range(self.structure.dimension -1):
            some_list = self.newfaces_lists[i]
            self.structure.maybe_newfaces[i] = some_list.data

        # Initialize ``visited_all``.
        self.structure.visited_all = <uint64_t **> self._mem.allocarray(self.coatoms.n_faces, sizeof(uint64_t *))
        self.structure.n_visited_all = <size_t *> self._mem.allocarray(self.structure.dimension, sizeof(size_t))
        self.structure.n_visited_all[self.structure.dimension -1] = 0
        if not C.is_bounded():
            # Treating the far face as if we had visited all its elements.
            # Hence we will visit all intersections of facets unless contained in the far face.

            # Regarding the length of ``self.visited_all``:
            # The last facet will not yield any new faces thus the length of ``visited_all``
            # needs to be at most ``n_facets - 1``.
            # Hence it is fine to use the first entry already for the far face,
            # as ``self.visited_all`` holds ``n_facets`` pointers.
            some_list = C.far_face()
            self.structure.visited_all[0] = some_list.data[0]
            self.structure.n_visited_all[self.structure.dimension -1] = 1

        # Initialize ``newfaces``, which will point to the new faces of codimension 1,
        # which have not been visited yet.
        self.structure.newfaces = <uint64_t ***> self._mem.allocarray(self.structure.dimension, sizeof(uint64_t **))
        for i in range(self.structure.dimension - 1):
            self.structure.newfaces[i] = <uint64_t **> self._mem.allocarray(self.coatoms.n_faces, sizeof(uint64_t *))
        self.structure.newfaces[self.structure.dimension - 1] = self.coatoms.data  # we start with coatoms

        # Initialize ``n_newfaces``.
        self.structure.n_newfaces = <size_t *> self._mem.allocarray(self.structure.dimension, sizeof(size_t))
        self.structure.n_newfaces[self.structure.dimension - 1] = self.coatoms.n_faces

        # Initialize ``first_time``.
        self.structure.first_time = <bint *> self._mem.allocarray(self.structure.dimension, sizeof(bint))
        self.structure.first_time[self.structure.dimension - 1] = True

        self.structure.yet_to_visit = self.coatoms.n_faces
        self.structure._index = 0

    def reset(self):
        r"""
        Reset the iterator.

        The iterator will start with the first face again.

        EXAMPLES::

            sage: P = polytopes.cube()
            sage: C = P.combinatorial_polyhedron()
            sage: it = C.face_iter()
            sage: next(it).ambient_V_indices()
            (0, 3, 4, 5)
            sage: it.reset()
            sage: next(it).ambient_V_indices()
            (0, 3, 4, 5)
        """
        if self.structure.dimension == 0 or self.coatoms.n_faces == 0:
            # As we will only yield proper faces,
            # there is nothing to yield in those cases.
            # We have to discontinue initialization,
            # as it assumes ``self.dimension > 0`` and ``self.n_faces > 0``.
            self.structure.current_dimension = self.structure.dimension
            return
        if self._bounded:
            self.structure.n_visited_all[self.structure.dimension -1] = 0
        else:
            self.structure.n_visited_all[self.structure.dimension -1] = 1
        self.structure.face = NULL
        self.structure.n_newfaces[self.structure.dimension - 1] = self.coatoms.n_faces
        self.structure.current_dimension = self.structure.dimension - 1
        self.structure.first_time[self.structure.dimension - 1] = True

        self.structure.yet_to_visit = self.coatoms.n_faces
        self.structure._index = 0

    def __next__(self):
        r"""
        Must be implemented by a derived class.

        TESTS::

            sage: from sage.geometry.polyhedron.combinatorial_polyhedron.face_iterator \
            ....:         import FaceIterator_base
            sage: P = polytopes.octahedron()
            sage: C = CombinatorialPolyhedron(P)
            sage: next(FaceIterator_base(C, False))
            Traceback (most recent call last):
            ...
            NotImplementedError: a derived class must implement this
        """
        raise NotImplementedError("a derived class must implement this")

    next = __next__

    def current(self):
        r"""
        Retrieve the last value of :meth:`next`.

        EXAMPLES::

            sage: P = polytopes.octahedron()
            sage: it = P.combinatorial_polyhedron().face_iter()
            sage: next(it)
            A 0-dimensional face of a 3-dimensional combinatorial polyhedron
            sage: it.current()
            A 0-dimensional face of a 3-dimensional combinatorial polyhedron
            sage: next(it).ambient_V_indices() == it.current().ambient_V_indices()
            True
        """
        if unlikely(self.structure.face is NULL):
            raise ValueError("iterator not set to a face yet")
        return CombinatorialFace(self)

    def __iter__(self):
        r"""
        EXAMPLES::

            sage: P = polytopes.simplex()
            sage: C = CombinatorialPolyhedron(P)
            sage: it = C.face_iter()
            sage: [d for d in it]
            [A 2-dimensional face of a 3-dimensional combinatorial polyhedron,
             A 2-dimensional face of a 3-dimensional combinatorial polyhedron,
             A 2-dimensional face of a 3-dimensional combinatorial polyhedron,
             A 2-dimensional face of a 3-dimensional combinatorial polyhedron,
             A 1-dimensional face of a 3-dimensional combinatorial polyhedron,
             A 1-dimensional face of a 3-dimensional combinatorial polyhedron,
             A 1-dimensional face of a 3-dimensional combinatorial polyhedron,
             A 0-dimensional face of a 3-dimensional combinatorial polyhedron,
             A 0-dimensional face of a 3-dimensional combinatorial polyhedron,
             A 0-dimensional face of a 3-dimensional combinatorial polyhedron,
             A 1-dimensional face of a 3-dimensional combinatorial polyhedron,
             A 1-dimensional face of a 3-dimensional combinatorial polyhedron,
             A 0-dimensional face of a 3-dimensional combinatorial polyhedron,
             A 1-dimensional face of a 3-dimensional combinatorial polyhedron]
        """
        return self

    def __reduce__(self):
        r"""
        Override __reduce__ to indicate that pickle/unpickle will not work.

        EXAMPLES::

            sage: P = polytopes.simplex()
            sage: C = CombinatorialPolyhedron(P)
            sage: it = C.face_iter()
            sage: it1 = loads(it.dumps())
            Traceback (most recent call last):
            ...
            NotImplementedError
        """
        raise NotImplementedError

    def ignore_subfaces(self):
        r"""
        The iterator will not visit any faces of the current face.

        Only possible when not in dual mode.

        EXAMPLES::

            sage: P = polytopes.Gosset_3_21()
            sage: C = CombinatorialPolyhedron(P)
            sage: it = C.face_iter(dual=False)
            sage: n_non_simplex_faces = 1
            sage: for face in it:
            ....:     if face.n_ambient_Vrepresentation() > face.dimension() + 1:
            ....:         n_non_simplex_faces += 1
            ....:     else:
            ....:         it.ignore_subfaces()
            ....:
            sage: n_non_simplex_faces
            127
        """
        if unlikely(self.dual):
            raise ValueError("only possible when not in dual mode")
        self.ignore_subsets()

    def ignore_supfaces(self):
        r"""
        The iterator will not visit any faces of the current face.

        Only possible when not in dual mode.

        EXAMPLES::

            sage: P = polytopes.Gosset_3_21()
            sage: C = CombinatorialPolyhedron(P)
            sage: it = C.face_iter(dual=True)
            sage: n_faces_with_non_simplex_quotient = 1
            sage: for face in it:
            ....:     if face.n_ambient_Hrepresentation() > C.dimension() - face.dimension() + 1:
            ....:         n_faces_with_non_simplex_quotient += 1
            ....:     else:
            ....:         it.ignore_supfaces()
            ....:
            sage: n_faces_with_non_simplex_quotient
            4845
        """
        if unlikely(not self.dual):
            raise ValueError("only possible when in dual mode")
        self.ignore_subsets()

    cdef int ignore_subsets(self) except -1:
        r"""
        Ignore sub-/supfaces of the current face.

        In non-dual mode ignores all subfaces of the current face.
        In dual mode ignores all supfaces of the current face.

        See :meth:`FaceIterator_base.ignore_subfaces` and
        :meth:`FaceIterator_base.ignore_supfaces`.
        """
        if unlikely(self.structure.face is NULL):
            raise ValueError("iterator not set to a face yet")
        # The current face is added to ``visited_all``.
        # This will make the iterator skip those faces.
        # Also, this face will not be added a second time to ``visited_all``,
        # as there are no new faces.
        self.structure.visited_all[self.structure.n_visited_all[self.structure.current_dimension]] = self.structure.face
        self.structure.n_visited_all[self.structure.current_dimension] += 1

    cdef inline CombinatorialFace next_face(self):
        r"""
        Set attribute ``face`` to the next face and return it as
        :class:`sage.geometry.polyhedron.combinatorial_polyhedron.combinatorial_face.CombinatorialFace`.
        """
        self.next_dimension()
        if unlikely(self.structure.current_dimension == self.structure.dimension):
            return None
        return CombinatorialFace(self)

    cdef inline int next_dimension(self) except -1:
        r"""
        Set attribute ``face`` to the next face and return the dimension.

        Will return the dimension of the polyhedron on failure.

        The function calls :meth:`FaceIterator_base.next_face_loop` until a new
        face is set or until the iterator is consumed.

        .. NOTE::

            The face_iterator can be prevented from visiting any subfaces
            (or supfaces in dual mode) as in :meth:`FaceIterator_base.ignore_subfaces`
            and :meth`FaceIterator_base.ignore_supfaces`.

            Those methods add the current face to ``visited_all`` before
            visiting sub-/supfaces instead of after. One cannot arbitrarily
            add faces to ``visited_all``, as visited_all has a maximal length.
        """
        return next_dimension(&self.structure)

    cdef inline int next_face_loop(self) except -1:
        r"""
        Set attribute ``face`` to the next face. On success return `1`.
        Otherwise `0`. Needs to be recalled then.

        If ``self.current_dimension == self.dimension``, then the iterator is
        consumed.
        """
        return next_face_loop(&self.structure)

    cdef inline size_t n_atom_rep(self) except -1:
        r"""
        Compute the number of atoms in the current face by counting the
        number of set bits.

        This is a shortcut of :class:`sage.geometry.polyhedron.combinatorial_polyhedron.combinatorial_face.CombinatorialFace.n_atom_rep`
        """
        return n_atom_rep(&self.structure)
        if self.structure.face:
            return count_atoms(self.structure.face, self.structure.face_length)

        # The face was not initialized properly.
        raise LookupError("face iterator does not point to a face")

    cdef size_t set_coatom_rep(self) except -1:
        r"""
        Set ``coatom_rep`` to be the coatom-representation of the current face.
        Return its length.

        This is a shortcut of :class:`sage.geometry.polyhedron.combinatorial_polyhedron.combinatorial_face.CombinatorialFace.set_coatom_rep`
        """
        cdef size_t n_coatoms = self.coatoms.n_faces
        cdef uint64_t **coatoms = self.coatoms.data
        cdef size_t face_length = self.structure.face_length
        return bit_rep_to_coatom_rep(self.structure.face, coatoms, n_coatoms,
                                       face_length, self.structure.coatom_rep)

    cdef size_t set_atom_rep(self) except -1:
        r"""
        Set ``atom_rep`` to be the atom-representation of the current face.
        Return its length.

        This is a shortcut of :class:`sage.geometry.polyhedron.combinatorial_polyhedron.combinatorial_face.CombinatorialFace.set_atom_rep`
        """
        cdef size_t face_length = self.structure.face_length
        return bit_rep_to_Vrep_list(self.structure.face, self.structure.atom_rep, face_length)

cdef class FaceIterator(FaceIterator_base):
    r"""
    A class to iterate over all combinatorial faces of a polyhedron.

    Construct all proper faces from the facets. In dual mode, construct all proper
    faces from the vertices. Dual will be faster for less vertices than facets.

    INPUT:

    - ``C`` -- a :class:`~sage.geometry.polyhedron.combinatorial_polyhedron.base.CombinatorialPolyhedron`
    - ``dual`` -- if ``True``, then dual polyhedron is used for iteration
      (only possible for bounded Polyhedra)
    - ``output_dimension`` -- if not ``None``, then the face iterator will only yield
      faces of this dimension

    .. SEEALSO::

        :class:`FaceIterator`,
        :class:`FaceIterator_geom`,
        :class:`~sage.geometry.polyhedron.combinatorial_polyhedron.base.CombinatorialPolyhedron`.

    EXAMPLES:

    Construct a face iterator::

        sage: P = polytopes.cuboctahedron()
        sage: C = CombinatorialPolyhedron(P)
        sage: it = C.face_iter()
        sage: next(it)
        A 0-dimensional face of a 3-dimensional combinatorial polyhedron

    Construct faces by the dual or not::

        sage: it = C.face_iter(dual=False)
        sage: next(it).dimension()
        2

        sage: it = C.face_iter(dual=True)
        sage: next(it).dimension()
        0

    For unbounded polyhedra only non-dual iteration is possible::

        sage: P = Polyhedron(rays=[[0,0,1], [0,1,0], [1,0,0]])
        sage: C = CombinatorialPolyhedron(P)
        sage: it = C.face_iter()
        sage: [face.ambient_Vrepresentation() for face in it]
        [(A vertex at (0, 0, 0),
          A ray in the direction (0, 1, 0),
          A ray in the direction (1, 0, 0)),
         (A vertex at (0, 0, 0),
          A ray in the direction (0, 0, 1),
          A ray in the direction (1, 0, 0)),
         (A vertex at (0, 0, 0),
          A ray in the direction (0, 0, 1),
          A ray in the direction (0, 1, 0)),
         (A vertex at (0, 0, 0), A ray in the direction (1, 0, 0)),
         (A vertex at (0, 0, 0), A ray in the direction (0, 1, 0)),
         (A vertex at (0, 0, 0),),
         (A vertex at (0, 0, 0), A ray in the direction (0, 0, 1))]
        sage: it = C.face_iter(dual=True)
        Traceback (most recent call last):
        ...
        ValueError: cannot iterate over dual of unbounded Polyedron

    Construct a face iterator only yielding dimension `2` faces::

        sage: P = polytopes.permutahedron(5)
        sage: C = CombinatorialPolyhedron(P)
        sage: it = C.face_iter(dimension=2)
        sage: counter = 0
        sage: for _ in it: counter += 1
        sage: print ('permutahedron(5) has', counter,
        ....:        'faces of dimension 2')
        permutahedron(5) has 150 faces of dimension 2
        sage: C.f_vector()
        (1, 120, 240, 150, 30, 1)

    In non-dual mode one can ignore all faces contained in the current face::

        sage: P = polytopes.cube()
        sage: C = CombinatorialPolyhedron(P)
        sage: it = C.face_iter(dual=False)
        sage: face = next(it)
        sage: face.ambient_H_indices()
        (5,)
        sage: it.ignore_subfaces()
        sage: [face.ambient_H_indices() for face in it]
        [(4,),
         (3,),
         (2,),
         (1,),
         (0,),
         (3, 4),
         (1, 4),
         (0, 4),
         (1, 3, 4),
         (0, 1, 4),
         (2, 3),
         (1, 3),
         (1, 2, 3),
         (1, 2),
         (0, 2),
         (0, 1, 2),
         (0, 1)]

        sage: it = C.face_iter(dual=True)
        sage: next(it)
        A 0-dimensional face of a 3-dimensional combinatorial polyhedron
        sage: it.ignore_subfaces()
        Traceback (most recent call last):
        ...
        ValueError: only possible when not in dual mode

    In dual mode one can ignore all faces that contain the current face::

        sage: it = C.face_iter(dual=True)
        sage: next(it)
        A 0-dimensional face of a 3-dimensional combinatorial polyhedron
        sage: face = next(it)
        sage: face.ambient_V_indices()
        (6,)
        sage: [face.ambient_V_indices() for face in it]
        [(5,),
         (4,),
         (3,),
         (2,),
         (1,),
         (0,),
         (6, 7),
         (4, 7),
         (2, 7),
         (4, 5, 6, 7),
         (1, 2, 6, 7),
         (2, 3, 4, 7),
         (5, 6),
         (1, 6),
         (0, 1, 5, 6),
         (4, 5),
         (0, 5),
         (0, 3, 4, 5),
         (3, 4),
         (2, 3),
         (0, 3),
         (0, 1, 2, 3),
         (1, 2),
         (0, 1)]

        sage: it = C.face_iter(dual=False)
        sage: next(it)
        A 2-dimensional face of a 3-dimensional combinatorial polyhedron
        sage: it.ignore_supfaces()
        Traceback (most recent call last):
        ...
        ValueError: only possible when in dual mode

    ALGORITHM:

    A (slightly generalized) description of the algorithm can be found in [KS2019]_.

    The algorithm to visit all proper faces exactly once is roughly
    equivalent to::

        faces = [set(facet) for facet in P.facets()]
        face_iterator(faces, [])

        def face_iterator(faces, visited_all):
            # Visit all faces of a polyhedron `P`, except those contained in
            # any of the visited all.

            # Assumes ``faces`` to be exactly those facets of `P`
            # that are not contained in any of the ``visited_all``.

            # Assumes ``visited_all`` to be some list of faces of
            # a polyhedron `P_2`, which contains `P` as one of its faces.

            while facets:
                one_face = faces.pop()
                maybe_newfaces = [one_face.intersection(face) for face in faces]

                # ``maybe_newfaces`` contains all facets of ``one_face``,
                # which we have not visited before.
                # Proof: Let `F` be a facet of ``one_face``.
                # We have a chain:
                # `P` ??? ``one_face`` ??? `F`.
                # By diamond property there exists ``second_face`` with:
                # `P` ??? ``second_face`` ??? `F`.

                # Either ``second_face`` is not an element of ``faces``:
                #     Hence ``second_face`` is contained in one of ``visited_all``.
                #     In particular, `F` is contained in ``visited_all``.
                # Or ``second_face`` is an element of ``faces``:
                #     Then, intersecting ``one_face`` with ``second_face`` gives
                #     ``F``. ???

                # If an element in ``maybe_newfaces`` is inclusion maximal
                # and not contained in any of the ``visited_all``,
                # it is a facet of ``one_face``.
                # Any facet in ``maybe_newfaces`` of ``one_face``
                # is inclusion maximal.
                maybe_newfaces2 = []
                for face1 in maybe_newfaces:
                    # ``face1`` is a facet of ``one_face``,
                    # iff it is not contained in another facet.
                    if all(not face1 < face2 for face2 in maybe_newfaces):
                        maybe_newfaces2.append(face1)

                # ``maybe_newfaces2`` contains only facets of ``one_face``
                # and some faces contained in any of ``visited_all``.
                # It also contains all the facets not contained in any of ``visited_all``.
                # Let ``newfaces`` be the list of all facets of ``one_face``
                # not contained in any of ``visited_all``.
                newfaces = []
                for face1 in maybe_newfaces2:
                    if all(not face1 < face2 for face2 in visited_all):
                        newfaces.append(face1)

                # By induction we can apply the algorithm, to visit all
                # faces of ``one_face`` not contained in ``visited_all``:
                face_iterator(newfaces, visited_all)

                # Finally visit ``one_face`` and add it to ``visited_all``:
                visit(one_face)
                visited_all.append(one_face)

                # Note: At this point, we have visited exactly those faces,
                # contained in any of the ``visited_all``.
    """
    def _repr_(self):
        r"""
        EXAMPLES::

            sage: P = polytopes.associahedron(['A',3])
            sage: C = CombinatorialPolyhedron(P)
            sage: C.face_iter()
            Iterator over the proper faces of a 3-dimensional combinatorial polyhedron

            sage: C.face_iter(1)
            Iterator over the 1-faces of a 3-dimensional combinatorial polyhedron
        """
        if self.structure.output_dimension != -2:
            if self.dual:
                # ouput_dimension is stored with respect to the dual
                intended_dimension = self.structure.dimension - 1 - self.structure.output_dimension
            else:
                intended_dimension = self.structure.output_dimension
            output = "Iterator over the {}-faces".format(intended_dimension)
        else:
            output = "Iterator over the proper faces"
        return output + " of a {}-dimensional combinatorial polyhedron".format(self.structure.dimension)

    def __next__(self):
        r"""
        Return the next face.

        EXAMPLES::

            sage: P = polytopes.cube()
            sage: C = CombinatorialPolyhedron(P)
            sage: it = C.face_iter()
            sage: [next(it) for _ in range(7)]
            [A 2-dimensional face of a 3-dimensional combinatorial polyhedron,
             A 2-dimensional face of a 3-dimensional combinatorial polyhedron,
             A 2-dimensional face of a 3-dimensional combinatorial polyhedron,
             A 2-dimensional face of a 3-dimensional combinatorial polyhedron,
             A 2-dimensional face of a 3-dimensional combinatorial polyhedron,
             A 2-dimensional face of a 3-dimensional combinatorial polyhedron,
             A 1-dimensional face of a 3-dimensional combinatorial polyhedron]
        """
        cdef CombinatorialFace face = self.next_face()
        if unlikely(self.structure.current_dimension == self.structure.dimension):
            raise StopIteration

        return face

cdef class FaceIterator_geom(FaceIterator_base):
    r"""
    A class to iterate over all geometric faces of a polyhedron.

    Construct all faces from the facets. In dual mode, construct all
    faces from the vertices. Dual will be faster for less vertices than facets.

    INPUT:

    - ``P`` -- an instance of :class:`~sage.geometry.polyhedron.base.Polyhedron_base`
    - ``dual`` -- if ``True``, then dual polyhedron is used for iteration
      (only possible for bounded Polyhedra)
    - ``output_dimension`` -- if not ``None``, then the FaceIterator will only yield
      faces of this dimension

    EXAMPLES:

    Construct a geometric face iterator::

        sage: P = polytopes.cuboctahedron()
        sage: it = P.face_generator()
        sage: next(it)
        A 3-dimensional face of a Polyhedron in ZZ^3 defined as the convex hull of 12 vertices

    Construct faces by the dual or not::

        sage: it = P.face_generator(dual=False)
        sage: _ = next(it), next(it)
        sage: next(it).dim()
        2

        sage: it = P.face_generator(dual=True)
        sage: _ = next(it), next(it)
        sage: next(it).dim()
        0

    For unbounded polyhedra only non-dual iteration is possible::

        sage: P = Polyhedron(rays=[[0,0,1], [0,1,0], [1,0,0]])
        sage: it = P.face_generator()
        sage: [face.ambient_Vrepresentation() for face in it]
        [(A vertex at (0, 0, 0),
          A ray in the direction (0, 0, 1),
          A ray in the direction (0, 1, 0),
          A ray in the direction (1, 0, 0)),
         (),
         (A vertex at (0, 0, 0),
          A ray in the direction (0, 1, 0),
          A ray in the direction (1, 0, 0)),
         (A vertex at (0, 0, 0),
          A ray in the direction (0, 0, 1),
          A ray in the direction (1, 0, 0)),
         (A vertex at (0, 0, 0),
          A ray in the direction (0, 0, 1),
          A ray in the direction (0, 1, 0)),
         (A vertex at (0, 0, 0), A ray in the direction (1, 0, 0)),
         (A vertex at (0, 0, 0), A ray in the direction (0, 1, 0)),
         (A vertex at (0, 0, 0),),
         (A vertex at (0, 0, 0), A ray in the direction (0, 0, 1))]
        sage: it = P.face_generator(dual=True)
        Traceback (most recent call last):
        ...
        ValueError: cannot iterate over dual of unbounded Polyedron

    Construct a FaceIterator only yielding dimension `2` faces::

        sage: P = polytopes.permutahedron(5)
        sage: it = P.face_generator(face_dimension=2)
        sage: counter = 0
        sage: for _ in it: counter += 1
        sage: print ('permutahedron(5) has', counter,
        ....:        'faces of dimension 2')
        permutahedron(5) has 150 faces of dimension 2
        sage: P.f_vector()
        (1, 120, 240, 150, 30, 1)

    In non-dual mode one can ignore all faces contained in the current face::

        sage: P = polytopes.cube()
        sage: it = P.face_generator(dual=False)
        sage: _ = next(it), next(it)
        sage: face = next(it)
        sage: face.ambient_H_indices()
        (5,)
        sage: it.ignore_subfaces()
        sage: [face.ambient_H_indices() for face in it]
        [(4,),
         (3,),
         (2,),
         (1,),
         (0,),
         (3, 4),
         (1, 4),
         (0, 4),
         (1, 3, 4),
         (0, 1, 4),
         (2, 3),
         (1, 3),
         (1, 2, 3),
         (1, 2),
         (0, 2),
         (0, 1, 2),
         (0, 1)]

        sage: it = P.face_generator(dual=True)
        sage: _ = next(it), next(it)
        sage: next(it)
        A 0-dimensional face of a Polyhedron in ZZ^3 defined as the convex hull of 1 vertex
        sage: it.ignore_subfaces()
        Traceback (most recent call last):
        ...
        ValueError: only possible when not in dual mode

    In dual mode one can ignore all faces that contain the current face::

        sage: P = polytopes.cube()
        sage: it = P.face_generator(dual=True)
        sage: _ = next(it), next(it)
        sage: next(it)
        A 0-dimensional face of a Polyhedron in ZZ^3 defined as the convex hull of 1 vertex
        sage: face = next(it)
        sage: face.ambient_V_indices()
        (6,)
        sage: [face.ambient_V_indices() for face in it]
        [(5,),
         (4,),
         (3,),
         (2,),
         (1,),
         (0,),
         (6, 7),
         (4, 7),
         (2, 7),
         (4, 5, 6, 7),
         (1, 2, 6, 7),
         (2, 3, 4, 7),
         (5, 6),
         (1, 6),
         (0, 1, 5, 6),
         (4, 5),
         (0, 5),
         (0, 3, 4, 5),
         (3, 4),
         (2, 3),
         (0, 3),
         (0, 1, 2, 3),
         (1, 2),
         (0, 1)]

        sage: it = P.face_generator(dual=False)
        sage: _ = next(it), next(it)
        sage: next(it)
        A 2-dimensional face of a Polyhedron in ZZ^3 defined as the convex hull of 4 vertices
        sage: it.ignore_supfaces()
        Traceback (most recent call last):
        ...
        ValueError: only possible when in dual mode

    .. SEEALSO::

        See :class:`FaceIterator`.
    """
    def __init__(self, P, dual=None, output_dimension=None):
        r"""
        Initialize :class:`FaceIterator_base`.

        See :class:`FaceIterator_base`.

        EXAMPLES::

            sage: P = polytopes.permutahedron(4)
            sage: it = P.face_generator()  # indirect doctest
            sage: it
            Iterator over the faces of a 3-dimensional polyhedron in ZZ^4
            sage: TestSuite(sage.geometry.polyhedron.combinatorial_polyhedron.face_iterator.FaceIterator_geom).run()
        """
        self._requested_dim = output_dimension

        if dual is None:
            # Determine the (likely) faster way, to iterate through all faces.
            if not P.is_compact() or P.n_facets() <= P.n_vertices():
                dual = False
            else:
                dual = True

        self.P = P

        if output_dimension is not None and (output_dimension < 0 or output_dimension >= P.dim()):
            # In those cases the output will be completely handled by :meth:`FaceIterator_geom.__next__`.
            output_dimension = None

        FaceIterator_base.__init__(self, P.combinatorial_polyhedron(), dual, output_dimension)
        self.reset()

    def reset(self):
        r"""
        Reset the iterator.

        The iterator will start with the first face again.

        EXAMPLES::

            sage: P = polytopes.cube()
            sage: it = P.face_generator()
            sage: next(it).ambient_V_indices()
            (0, 1, 2, 3, 4, 5, 6, 7)
            sage: next(it).ambient_V_indices()
            ()
            sage: next(it).ambient_V_indices()
            (0, 3, 4, 5)
            sage: it.reset()
            sage: next(it).ambient_V_indices()
            (0, 1, 2, 3, 4, 5, 6, 7)
            sage: next(it).ambient_V_indices()
            ()
            sage: next(it).ambient_V_indices()
            (0, 3, 4, 5)
        """
        output_dimension = self._requested_dim
        P = self.P

        if output_dimension is None:
            if P.dim() == -1:
                self._trivial_faces = 1  # the empty polyhedron, only yield the empty face
            else:
                self._trivial_faces = 2  # yield the universe, then the empty face, than all other faces
        elif output_dimension == P.dim():
            self._trivial_faces = 4  # only yield the full-dimensional face and no other faces
        elif output_dimension == -1:
            self._trivial_faces = 3  # only yield the empty face and no other faces
        elif output_dimension < -1 or output_dimension > P.dim():
            self._trivial_faces = -1  # don't yield any faces at all
        else:
            self._trivial_faces = 0  # yield the faces of the requested dimension
        FaceIterator_base.reset(self)

    def _repr_(self):
        r"""
        EXAMPLES::

            sage: P = polytopes.associahedron(['A',3])
            sage: P.face_generator()
            Iterator over the faces of a 3-dimensional polyhedron in QQ^3

            sage: P.face_generator(1)
            Iterator over the 1-faces of a 3-dimensional polyhedron in QQ^3
        """
        if self._requested_dim is not None:
            output = "Iterator over the {}-faces".format(self._requested_dim)
        else:
            output = "Iterator over the faces"
        return output + " of a {}-dimensional polyhedron in {}".format(self.structure.dimension, self.P.parent()._repr_ambient_module())

    def __next__(self):
        r"""
        Return the next face.

        EXAMPLES::

            sage: P = polytopes.cube()
            sage: it = P.face_generator()
            sage: [next(it) for _ in range(7)]
            [A 3-dimensional face of a Polyhedron in ZZ^3 defined as the convex hull of 8 vertices,
             A -1-dimensional face of a Polyhedron in ZZ^3,
             A 2-dimensional face of a Polyhedron in ZZ^3 defined as the convex hull of 4 vertices,
             A 2-dimensional face of a Polyhedron in ZZ^3 defined as the convex hull of 4 vertices,
             A 2-dimensional face of a Polyhedron in ZZ^3 defined as the convex hull of 4 vertices,
             A 2-dimensional face of a Polyhedron in ZZ^3 defined as the convex hull of 4 vertices,
             A 2-dimensional face of a Polyhedron in ZZ^3 defined as the convex hull of 4 vertices]
        """
        if unlikely(self._trivial_faces):
            if self._trivial_faces == -1:
                raise StopIteration
            if self._trivial_faces in (2,4):  # Return the polyhedron.
                if self._trivial_faces == 2:
                    self._trivial_faces = 1  # Return the empty face next.
                else:
                    self._trivial_faces = -1  # The iterator is exhausted.
                equations = [eq.index() for eq in self.P.equation_generator()]
                return PolyhedronFace(self.P, range(self.P.n_Vrepresentation()), equations)
            else:  # Return the empty face.
                if self._trivial_faces == 1:
                    self._trivial_faces = 0  # Return the proper faces next.
                else:
                    self._trivial_faces = -1  # The iterator is exhausted.
                return PolyhedronFace(self.P, [], range(self.P.n_Hrepresentation()))

        self.next_dimension()
        if unlikely(self.structure.current_dimension == self.structure.dimension):
            raise StopIteration
        return self.current()

    def current(self):
        r"""
        Retrieve the last value of :meth:`__next__`.

        EXAMPLES::

            sage: P = polytopes.octahedron()
            sage: it = P.face_generator()
            sage: _ = next(it), next(it)
            sage: next(it)
            A 0-dimensional face of a Polyhedron in ZZ^3 defined as the convex hull of 1 vertex
            sage: it.current()
            A 0-dimensional face of a Polyhedron in ZZ^3 defined as the convex hull of 1 vertex
            sage: next(it).ambient_V_indices() == it.current().ambient_V_indices()
            True
        """
        return combinatorial_face_to_polyhedral_face(self.P, FaceIterator_base.current(self))

# Nogil definitions of crucial functions.

cdef inline int next_dimension(iter_struct *structptr) nogil except -1:
    r"""
    See :meth:`FaceIterator.next_dimension`.
    """
    cdef int dim = structptr[0].dimension
    while (not next_face_loop(structptr)) and (structptr[0].current_dimension < dim):
        sig_check()
    structptr[0]._index += 1
    return structptr[0].current_dimension

cdef inline int next_face_loop(iter_struct *structptr) nogil except -1:
    r"""
    See :meth:`FaceIterator.next_face_loop`.
    """
    if unlikely(structptr[0].current_dimension == structptr[0].dimension):
        # The function is not supposed to be called,
        # just prevent it from crashing.
        raise StopIteration

    # Getting ``[faces, n_faces, n_visited_all]`` according to dimension.
    cdef uint64_t **faces = structptr[0].newfaces[structptr[0].current_dimension]
    cdef size_t n_faces = structptr[0].n_newfaces[structptr[0].current_dimension]
    cdef size_t n_visited_all = structptr[0].n_visited_all[structptr[0].current_dimension]

    if (structptr[0].output_dimension > -2) and (structptr[0].output_dimension != structptr[0].current_dimension):
        # If only a specific dimension was requested (i.e. ``output_dimension > -2``),
        # then we will not yield faces in other dimension.
        structptr[0].yet_to_visit = 0

    if structptr[0].yet_to_visit:
        # Set ``face`` to the next face.
        structptr[0].yet_to_visit -= 1
        structptr[0].face = faces[structptr[0].yet_to_visit]
        return 1

    if structptr[0].current_dimension <= structptr[0].lowest_dimension:
        # We will not yield the empty face.
        # We will not yield below requested dimension.
        structptr[0].current_dimension += 1
        return 0

    if n_faces <= 1:
        # There will be no more faces from intersections.
        structptr[0].current_dimension += 1
        return 0

    # We will visit the last face now.
    structptr[0].n_newfaces[structptr[0].current_dimension] -= 1
    n_faces -= 1

    if not structptr[0].first_time[structptr[0].current_dimension]:
        # In this case there exists ``faces[n_faces + 1]``, of which we
        # have visited all faces, but which was not added to
        # ``visited_all`` yet.
        structptr[0].visited_all[n_visited_all] = faces[n_faces + 1]
        structptr[0].n_visited_all[structptr[0].current_dimension] += 1
        n_visited_all = structptr[0].n_visited_all[structptr[0].current_dimension]
    else:
        # Once we have visited all faces of ``faces[n_faces]``, we want
        # to add it to ``visited_all``.
        structptr[0].first_time[structptr[0].current_dimension] = False

    # Get the faces of codimension 1 contained in ``faces[n_faces]``,
    # which we have not yet visited.
    cdef size_t newfacescounter

    sig_on()
    newfacescounter = get_next_level(
        faces, n_faces + 1, structptr[0].maybe_newfaces[structptr[0].current_dimension-1],
        structptr[0].newfaces[structptr[0].current_dimension-1],
        structptr[0].visited_all, n_visited_all, structptr[0].face_length)
    sig_off()

    if newfacescounter:
        # ``faces[n_faces]`` contains new faces.
        # We will visted them on next call, starting with codimension 1.

        # Setting the variables correclty for next call of ``next_face_loop``.
        structptr[0].current_dimension -= 1
        structptr[0].first_time[structptr[0].current_dimension] = True
        structptr[0].n_newfaces[structptr[0].current_dimension] = newfacescounter
        structptr[0].n_visited_all[structptr[0].current_dimension] = n_visited_all
        structptr[0].yet_to_visit = newfacescounter
        return 0
    else:
        # ``faces[n_faces]`` contains no new faces.
        # Hence there is no need to add it to ``visited_all``.
        # NOTE:
        #     For the methods ``ignore_subfaces`` and ``ignore_supfaces``
        #     this step needs to be done, as ``faces[n_faces]`` might
        #     have been added manually to ``visited_all``.
        #     So this step is required to respect boundaries of ``visited_all``.
        structptr[0].first_time[structptr[0].current_dimension] = True
        return 0

cdef inline size_t n_atom_rep(iter_struct *structptr) nogil except -1:
    r"""
    See meth:`FaceIterator.n_atom_rep`.
    """
    if structptr[0].face:
        return count_atoms(structptr[0].face, structptr[0].face_length)

    # The face was not initialized properly.
    raise LookupError("``FaceIterator`` does not point to a face")
