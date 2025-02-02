import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import DesignOverlay from '~/design_management/components/design_overlay.vue';
import { resolvers } from '~/design_management/graphql';
import activeDiscussionQuery from '~/design_management/graphql/queries/active_discussion.query.graphql';
import notes from '../mock_data/notes';

Vue.use(VueApollo);

describe('Design overlay component', () => {
  let wrapper;
  let apolloProvider;

  const mockDimensions = { width: 100, height: 100 };

  const findOverlay = () => wrapper.find('[data-testid="design-overlay"]');
  const findAllNotes = () => wrapper.findAll('[data-testid="note-pin"]');
  const findCommentBadge = () => wrapper.find('[data-testid="comment-badge"]');
  const findBadgeAtIndex = (noteIndex) => findAllNotes().at(noteIndex);
  const findFirstBadge = () => findBadgeAtIndex(0);
  const findSecondBadge = () => findBadgeAtIndex(1);

  const clickAndDragBadge = async (elem, fromPoint, toPoint) => {
    elem.vm.$emit(
      'mousedown',
      new MouseEvent('click', { clientX: fromPoint.x, clientY: fromPoint.y }),
    );
    findOverlay().trigger('mousemove', { clientX: toPoint.x, clientY: toPoint.y });
    await nextTick();
    elem.vm.$emit('mouseup', new MouseEvent('click', { clientX: toPoint.x, clientY: toPoint.y }));
    await nextTick();
  };

  function createComponent(props = {}, data = {}) {
    apolloProvider = createMockApollo([], resolvers);
    apolloProvider.clients.defaultClient.writeQuery({
      query: activeDiscussionQuery,
      data: {
        activeDiscussion: {
          __typename: 'ActiveDiscussion',
          id: null,
          source: null,
        },
      },
    });

    wrapper = shallowMount(DesignOverlay, {
      apolloProvider,
      propsData: {
        dimensions: mockDimensions,
        position: {
          top: '0',
          left: '0',
        },
        resolvedDiscussionsExpanded: false,
        ...props,
      },
      data() {
        return {
          activeDiscussion: {
            id: null,
            source: null,
          },
          ...data,
        };
      },
    });
  }

  afterEach(() => {
    apolloProvider = null;
  });

  it('should have correct inline style', () => {
    createComponent();

    expect(wrapper.attributes().style).toBe('width: 100px; height: 100px; top: 0px; left: 0px;');
  });

  it('should emit `openCommentForm` when clicking on overlay', async () => {
    createComponent();
    const newCoordinates = {
      x: 10,
      y: 10,
    };

    wrapper
      .find('[data-qa-selector="design_image_button"]')
      .trigger('mouseup', { offsetX: newCoordinates.x, offsetY: newCoordinates.y });
    await nextTick();
    expect(wrapper.emitted('openCommentForm')).toEqual([
      [{ x: newCoordinates.x, y: newCoordinates.y }],
    ]);
  });

  describe('with notes', () => {
    it('should render only the first note', () => {
      createComponent({
        notes,
      });
      expect(findAllNotes()).toHaveLength(1);
    });

    describe('with resolved discussions toggle expanded', () => {
      beforeEach(() => {
        createComponent({
          notes,
          resolvedDiscussionsExpanded: true,
        });
      });

      it('should render all notes', () => {
        expect(findAllNotes()).toHaveLength(notes.length);
      });

      it('should have set the correct position for each note badge', () => {
        expect(findFirstBadge().props('position')).toEqual({
          left: '10px',
          top: '15px',
        });
        expect(findSecondBadge().props('position')).toEqual({ left: '50px', top: '50px' });
      });

      it('should apply resolved class to the resolved note pin', () => {
        expect(findSecondBadge().props('isResolved')).toBe(true);
      });

      describe('when no discussion is active', () => {
        it('should not apply inactive class to any pins', () => {
          expect(
            findAllNotes(0).wrappers.every((designNote) => designNote.classes('gl-bg-blue-50')),
          ).toBe(false);
        });
      });

      describe('when a discussion is active', () => {
        it.each([notes[0].discussion.notes.nodes[1], notes[0].discussion.notes.nodes[0]])(
          'should not apply inactive class to the pin for the active discussion',
          async (note) => {
            apolloProvider.clients.defaultClient.writeQuery({
              query: activeDiscussionQuery,
              data: {
                activeDiscussion: {
                  __typename: 'ActiveDiscussion',
                  id: note.id,
                  source: 'discussion',
                },
              },
            });

            await nextTick();
            expect(findBadgeAtIndex(0).props('isInactive')).toBe(false);
          },
        );

        it('should apply inactive class to all pins besides the active one', async () => {
          apolloProvider.clients.defaultClient.writeQuery({
            query: activeDiscussionQuery,
            data: {
              activeDiscussion: {
                __typename: 'ActiveDiscussion',
                id: notes[0].id,
                source: 'discussion',
              },
            },
          });

          await nextTick();
          expect(findSecondBadge().props('isInactive')).toBe(true);
          expect(findFirstBadge().props('isInactive')).toBe(false);
        });
      });
    });

    it('should recalculate badges positions on window resize', async () => {
      createComponent({
        notes,
        dimensions: {
          width: 400,
          height: 400,
        },
      });

      expect(findFirstBadge().props('position')).toEqual({ left: '40px', top: '60px' });

      wrapper.setProps({
        dimensions: {
          width: 200,
          height: 200,
        },
      });

      await nextTick();
      expect(findFirstBadge().props('position')).toEqual({ left: '20px', top: '30px' });
    });

    it('should update active discussion when clicking a note without moving it', async () => {
      createComponent({
        notes,
        dimensions: {
          width: 400,
          height: 400,
        },
      });

      expect(findFirstBadge().props('isInactive')).toBe(null);

      const note = notes[0];
      const { position } = note;

      findFirstBadge().vm.$emit(
        'mousedown',
        new MouseEvent('click', { clientX: position.x, clientY: position.y }),
      );

      await nextTick();
      findFirstBadge().vm.$emit(
        'mouseup',
        new MouseEvent('click', { clientX: position.x, clientY: position.y }),
      );
      await waitForPromises();
      expect(findFirstBadge().props('isInactive')).toBe(false);
    });
  });

  describe('when moving notes', () => {
    it('should emit `moveNote` event when note-moving action ends', async () => {
      createComponent({ notes });
      const note = notes[0];
      const { position } = note;
      const newCoordinates = { x: 20, y: 20 };

      const badge = findFirstBadge();
      await clickAndDragBadge(badge, { x: position.x, y: position.y }, newCoordinates);

      expect(wrapper.emitted('moveNote')).toEqual([
        [
          {
            noteId: notes[0].id,
            discussionId: notes[0].discussion.id,
            coordinates: newCoordinates,
          },
        ],
      ]);
    });

    describe('without [repositionNote] permission', () => {
      const mockNoteNotAuthorised = {
        ...notes[0],
        userPermissions: {
          repositionNote: false,
        },
      };

      const mockNoteCoordinates = {
        x: mockNoteNotAuthorised.position.x,
        y: mockNoteNotAuthorised.position.y,
      };

      it('should be unable to move a note', async () => {
        createComponent({
          dimensions: mockDimensions,
          notes: [mockNoteNotAuthorised],
        });

        const badge = findAllNotes().at(0);
        await clickAndDragBadge(badge, { ...mockNoteCoordinates }, { x: 20, y: 20 });
        // note position should not change after a click-and-drag attempt
        expect(findFirstBadge().props('position')).toEqual({
          left: `${mockNoteCoordinates.x}px`,
          top: `${mockNoteCoordinates.y}px`,
        });
      });
    });
  });

  describe('with a new form', () => {
    it('should render a new comment badge', () => {
      createComponent({
        currentCommentForm: {
          ...notes[0].position,
        },
      });

      expect(findCommentBadge().exists()).toBe(true);
      expect(findCommentBadge().props('position')).toEqual({ left: '10px', top: '15px' });
    });

    describe('when moving the comment badge', () => {
      it('should update badge style when note-moving action ends', async () => {
        const { position } = notes[0];
        createComponent({
          currentCommentForm: {
            ...position,
          },
        });

        const commentBadge = findCommentBadge();
        const toPoint = { x: 20, y: 20 };

        await clickAndDragBadge(commentBadge, { x: position.x, y: position.y }, toPoint);
        commentBadge.vm.$emit('mouseup', new MouseEvent('click'));
        // simulates the currentCommentForm being updated in index.vue component, and
        // propagated back down to this prop
        wrapper.setProps({
          currentCommentForm: { height: position.height, width: position.width, ...toPoint },
        });

        await nextTick();
        expect(commentBadge.props('position')).toEqual({ left: '20px', top: '20px' });
      });

      it('should emit `openCommentForm` event when mouseleave fired on overlay element', async () => {
        const { position } = notes[0];
        createComponent({
          notes,
          currentCommentForm: {
            ...position,
          },
        });

        const newCoordinates = { x: 20, y: 20 };

        await clickAndDragBadge(
          findCommentBadge(),
          { x: position.x, y: position.y },
          newCoordinates,
        );

        wrapper.trigger('mouseleave');
        await nextTick();
        expect(wrapper.emitted('openCommentForm')).toEqual([[newCoordinates]]);
      });

      it('should emit `openCommentForm` event when mouseup fired on comment badge element', async () => {
        const { position } = notes[0];
        createComponent({
          notes,
          currentCommentForm: {
            ...position,
          },
        });

        const newCoordinates = { x: 20, y: 20 };

        await clickAndDragBadge(
          findCommentBadge(),
          { x: position.x, y: position.y },
          newCoordinates,
        );

        expect(wrapper.emitted('openCommentForm')).toEqual([[newCoordinates]]);
      });
    });
  });
});
