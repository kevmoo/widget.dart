part of effects;

/**
 * [Swapper] is an effect that builds on top of [ShowHide] to manage the visibility
 * of a number of children contained in a parent element.
 *
 * Provide a parent element and either a target child element or an index to a
 * target child element and [Swapper] will display the target while hiding other
 * visible elements using the provided effects, duration, and timing.
 *
 * [Swapper] is encapsulated into a component by [Swap].
 */
class Swapper {

  /**
   * [effect] is used as the [hideEffect] unless [hideEffect] is provided.
   */
  static Future<bool> swap(List<Element> children, Element child,
      {ShowHideEffect effect, int duration, EffectTiming effectTiming, ShowHideEffect hideEffect}) {

    assert(children != null);

    if(hideEffect == null) {
      hideEffect = effect;
    }

    if(child == null) {
      // hide everything
      // NOTE: all visible items will have the same animation run, which might be weird
      //       hmm...
      return _hideEverything(children, hideEffect, duration, effectTiming);
    }

    if(!children.contains(child)) {
      throw new ArgumentError('child is not one of children');
    }

    // ensure at most one child of the host is visible before beginning
    return _ensureOneShown(children)
        .then((Element currentlyVisible) {
          if(currentlyVisible == null) {
            return new Future.value(false);
          } else if(currentlyVisible == child) {
            // target element is already shown
            return new Future.value(true);
          }

          child.style.zIndex = '2';
          final showFuture = ShowHide.show(child, effect: effect, duration: duration, effectTiming: effectTiming);

          currentlyVisible.style.zIndex = '1';
          final hideFuture = ShowHide.hide(currentlyVisible, effect: hideEffect, duration: duration, effectTiming: effectTiming);

          return Future.wait([showFuture, hideFuture])
              .then((List<ShowHideResult> results) {
                [child, currentlyVisible].forEach((e) => e.style.zIndex = '');
                return results.every((a) => a.isSuccess);
              });
        });
  }

  static Future<bool> _hideEverything(List<Element> children, ShowHideEffect effect, int duration, EffectTiming effectTiming) {
    var futures = children.map((e) => ShowHide.hide(e, effect: effect, duration: duration, effectTiming: effectTiming));
    return Future.wait(futures)
        .then((List<ShowHideResult> successList) =>
            successList.every((v) => v.isSuccess));
  }

  static Future<Element> _ensureOneShown(List<Element> children) {
    assert(children != null);
    if(children.length == 0) {
      // no elements to show
      return new Future.value(null);
    } else if(children.length == 1) {
      final child = children[0];
      return ShowHide.show(child)
          .then((ShowHideResult result) {
            if(result.isSuccess) {
              return child;
            } else {
              return null;
            }
          });
    }

    // 1 - get states of all children
    final theStates = children
        .map(ShowHide.getState).toList();

    int shownIndex = null;

    return new Future.value(theStates)
        .then((List<ShowHideState> states) {
          // paranoid sanity check that at lesat the count of items
          // before and after haven't changed
          assert(states.length == children.length);

          // See how many of the items are actually shown
          final showIndicies = new List<int>();
          for(int i=0; i<states.length;i++) {
            if(states[i].isShow) {
              showIndicies.add(i);
            }
          }

          if(showIndicies.length == 0) {
            // show last item -> likely the visible one
            shownIndex = children.length-1;

            return ShowHide.show(children[shownIndex])
                .then((ShowHideResult r) => r.isSuccess);
          } else if(showIndicies.length > 1) {
            // if more than one is shown, hide all but the last one
            final toHide = showIndicies
                .sublist(0, showIndicies.length - 1)
                .map((int index) => children[index]).toList();
            shownIndex = showIndicies[showIndicies.length - 1];
            return _hideAll(toHide);
          } else {
            assert(showIndicies.length == 1);
            shownIndex = showIndicies[0];
            // only one is shown...so...leave it
            return true;
          }
        })
        .then((bool success) {
          assert(success == true || success == false);
          assert(shownIndex != null);
          if(success) {
            return children[shownIndex];
          } else {
            return null;
          }
        });
  }

  static Future<bool> _hideAll(List<Element> children) =>
    Future.wait(children.map(ShowHide.hide))
    .then((List<ShowHideResult> successValues) =>
        successValues.every((v) => v.isSuccess));
}
