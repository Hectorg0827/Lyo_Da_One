package com.lyo.app.ui.screens.home

import android.content.Intent
import android.widget.Toast
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.SmartToy
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.google.gson.JsonObject
import com.lyo.app.data.Session
import com.lyo.app.data.StackRepository
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CourseDto
import com.lyo.app.data.api.DueReviewItemDto
import com.lyo.app.data.api.StackItemDto
import com.lyo.app.ui.components.CardGradients
import com.lyo.app.ui.components.GlassCard
import com.lyo.app.ui.components.LoadingBox
import com.lyo.app.ui.components.SectionHeader
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.LyoAmber
import com.lyo.app.ui.theme.LyoBlue
import com.lyo.app.ui.theme.LyoGreen
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.launch

@Composable
fun HomeScreen(nav: NavHostController) {
    var overview by remember { mutableStateOf<JsonObject?>(null) }
    var featuredCourses by remember { mutableStateOf<List<CourseDto>>(emptyList()) }
    var courseStacks by remember { mutableStateOf<List<StackItemDto>>(emptyList()) }
    var dueReviews by remember { mutableStateOf<List<DueReviewItemDto>>(emptyList()) }
    var reviewError by remember { mutableStateOf<String?>(null) }
    var catalogError by remember { mutableStateOf<String?>(null) }
    var loaded by remember { mutableStateOf(false) }
    var stackFilter by remember { mutableStateOf(FocusPresentation.Filter.All) }
    // Saved courses start stacked, and open on a tap. See the deck below.
    var deckExpanded by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        runCatching { ApiClient.api.gamificationOverview() }
            .onSuccess { overview = it }

        runCatching { ApiClient.api.courses(0, 5) }
            .onSuccess {
                featuredCourses = it
                catalogError = null
            }
            .onFailure {
                catalogError = it.localizedMessage ?: "The course catalog is unavailable."
            }

        // Device- and platform-agnostic — the same list backs Focus/Home
        // on any device the user is signed into, unlike the old single-
        // slot RecentCourseStore this replaces (StackRepository is
        // internally resilient; an empty list here just means "none yet"
        // or "sync failed," handled identically by EmptyLearningCard below).
        courseStacks = StackRepository.listCourseStacks()

        runCatching { ApiClient.api.dueReviews() }
            .onSuccess {
                dueReviews = it.items
                reviewError = null
            }
            .onFailure {
                reviewError = "Your review schedule could not be loaded right now."
            }

        loaded = true
    }

    if (!loaded) {
        LoadingBox()
        return
    }

    val streak = runCatching {
        overview?.getAsJsonObject("streaks")?.get("current")?.asInt
    }.getOrNull() ?: Session.user?.streak ?: 0
    val xp = runCatching {
        overview?.getAsJsonObject("xp_summary")?.get("total")?.asInt
    }.getOrNull() ?: Session.user?.resolvedXp ?: 0
    val level = runCatching {
        overview?.getAsJsonObject("user_level")?.get("level")?.asInt
    }.getOrNull() ?: Session.user?.resolvedLevel ?: 1

    LazyColumn(
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        modifier = Modifier.fillMaxSize(),
    ) {
        item {
            androidx.compose.material3.Button(onClick = { nav.navigate(Routes.TEST_PREP) }, modifier = Modifier.fillMaxWidth()) {
                Text("I have a test · Start or resume")
            }
        }
        item {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(
                    text = "Hi, ${Session.user?.displayName ?: "Learner"}",
                    style = MaterialTheme.typography.headlineMedium,
                    color = TextPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                IconButton(onClick = { nav.navigate(Routes.NOTIFICATIONS) }) {
                    Icon(
                        Icons.Filled.Notifications,
                        contentDescription = "Notifications",
                        tint = TextSecondary,
                    )
                }
                IconButton(onClick = { nav.navigate(Routes.MESSAGES) }) {
                    Icon(
                        Icons.Filled.Email,
                        contentDescription = "Messages",
                        tint = TextSecondary,
                    )
                }
                IconButton(onClick = { nav.navigate(Routes.SETTINGS) }) {
                    Icon(
                        Icons.Filled.Settings,
                        contentDescription = "Settings",
                        tint = TextSecondary,
                    )
                }
            }
        }

        item {
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                StatCard(
                    emoji = "🔥",
                    value = "$streak",
                    label = "Day streak",
                    accent = LyoAmber,
                    modifier = Modifier.weight(1f),
                )
                StatCard(
                    emoji = "⚡",
                    value = "$xp",
                    label = "XP earned",
                    accent = LyoPurple,
                    modifier = Modifier.weight(1f),
                )
                StatCard(
                    emoji = "🏆",
                    value = "$level",
                    label = "Level",
                    accent = LyoGreen,
                    modifier = Modifier.weight(1f),
                )
            }
        }

        if (dueReviews.isNotEmpty() || reviewError != null) {
            item {
                SectionHeader("Ready to review")
                when {
                    dueReviews.isNotEmpty() -> {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            dueReviews.take(3).forEach { review ->
                                val title = review.skillName?.takeIf { it.isNotBlank() }
                                    ?: humanizeSkillId(review.skillId)
                                GlassCard(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable {
                                            nav.navigate(
                                                Routes.reviewClassroom(
                                                    skillId = review.skillId,
                                                    topic = title,
                                                ),
                                            )
                                        },
                                ) {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        modifier = Modifier.padding(14.dp),
                                    ) {
                                        Icon(
                                            Icons.Filled.MenuBook,
                                            contentDescription = null,
                                            tint = LyoPurple,
                                            modifier = Modifier.size(22.dp),
                                        )
                                        Column(
                                            modifier = Modifier
                                                .weight(1f)
                                                .padding(start = 10.dp),
                                        ) {
                                            Text(
                                                text = title,
                                                style = MaterialTheme.typography.titleSmall,
                                                color = TextPrimary,
                                            )
                                            Text(
                                                text = when {
                                                    review.daysOverdue <= 0 ->
                                                        "Due now · fresh retrieval"
                                                    review.daysOverdue == 1 ->
                                                        "1 day overdue · fresh retrieval"
                                                    else ->
                                                        "${review.daysOverdue} days overdue · fresh retrieval"
                                                },
                                                style = MaterialTheme.typography.bodySmall,
                                                color = TextSecondary,
                                                modifier = Modifier.padding(top = 2.dp),
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                    else -> GlassCard(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = reviewError
                                ?: "Your review schedule could not be loaded right now.",
                            style = MaterialTheme.typography.bodySmall,
                            color = TextSecondary,
                            modifier = Modifier.padding(14.dp),
                        )
                    }
                }
            }
        }

        item {
            // "Your Stacks" is the heading the cross-platform contract pins
            // (scripts/verify-android-focus-honesty.mjs), so it stays.
            //
            // What changed is underneath it. This was a LazyRow of 220dp
            // cards, which showed three of a learner's courses and hid the
            // rest behind a sideways scroll nothing signalled. It is now the
            // whole list, newest first, as full-width cards that turn over
            // for the description the backend already sends and this screen
            // used to drop — matching the iOS Focus tab and web Home.
            SectionHeader("Your Stacks")
            if (courseStacks.isNotEmpty()) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState())
                        .padding(bottom = 10.dp),
                ) {
                    FocusPresentation.Filter.entries.forEach { filter ->
                        val count = FocusPresentation.countFor(courseStacks, filter)
                        FilterChip(
                            selected = stackFilter == filter,
                            onClick = { stackFilter = filter },
                            label = { Text("${filter.label} $count") },
                        )
                    }
                }

                val visible = courseStacks.filter { FocusPresentation.matches(it, stackFilter) }
                if (visible.isEmpty()) {
                    Text(
                        text = "No courses in this filter.",
                        style = MaterialTheme.typography.bodySmall,
                        color = TextSecondary,
                        modifier = Modifier.padding(vertical = 20.dp),
                    )
                } else {
                    // Saved courses, as a deck that opens.
                    //
                    // Shut, it is one card with the rest of the library
                    // stacked under it, so a screenful of courses does not
                    // begin as a wall of cards. Its Resume button is live in
                    // that state — only the card body's tap is taken over —
                    // so a learner coming back to a course never has to open
                    // the deck first.
                    //
                    // Open, it is one row that scrolls sideways and snaps
                    // card to card. The whole library then costs the screen
                    // one card's height instead of one per course.
                    val layers = FocusPresentation.deckLayers(visible.size)
                    // `deckExpanded` alone is not enough. A learner can open
                    // the deck and then pick a filter holding one course, and
                    // an open deck over one card is a lone narrowed card in a
                    // LazyRow with its own control gone. Asking the rule on
                    // every composition means the deck closes itself, and
                    // opens again when a filter with more courses comes back.
                    val deckOpen = deckExpanded && FocusPresentation.deckCanOpen(visible.size)

                    Column {
                        if (deckOpen) {
                            // Each card stops short of the container so the
                            // next one's edge is always showing. A card the
                            // full width of the screen would put every course
                            // after the first behind a swipe nothing signals,
                            // which is the mistake the LazyRow of small cards
                            // this replaced already made. The width and the
                            // gap come from FocusPresentation, so iOS and web
                            // leave the same sliver showing.
                            BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
                                val cardWidth = FocusPresentation.deckCardWidth(maxWidth.value).dp
                                val rowState = rememberLazyListState()
                                LazyRow(
                                    state = rowState,
                                    flingBehavior = rememberSnapFlingBehavior(rowState),
                                    horizontalArrangement = Arrangement.spacedBy(
                                        FocusPresentation.DECK_CARD_GAP.dp,
                                    ),
                                ) {
                                    itemsIndexed(visible, key = { _, row -> row.id }) { index, stackItem ->
                                        // Cards arrive one after another
                                        // rather than all at once, which is
                                        // what makes the deck read as opening
                                        // instead of simply appearing. The
                                        // delays are shared with iOS and web,
                                        // and capped.
                                        var arrived by remember { mutableStateOf(false) }
                                        LaunchedEffect(Unit) { arrived = true }
                                        val appear by animateFloatAsState(
                                            targetValue = if (arrived) 1f else 0f,
                                            animationSpec = tween(
                                                durationMillis = 260,
                                                delayMillis = FocusPresentation.deckStaggerMilliseconds(index),
                                            ),
                                            label = "deckCardAppear",
                                        )

                                        Box(
                                            modifier = Modifier
                                                .width(cardWidth)
                                                .graphicsLayer {
                                                    alpha = appear
                                                    scaleX = 0.96f + 0.04f * appear
                                                    scaleY = 0.96f + 0.04f * appear
                                                },
                                        ) {
                                            StackDeckCard(item = stackItem, nav = nav)
                                        }
                                    }
                                }
                            }
                        } else {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    // Room for the peek cards, which are
                                    // offset rather than laid out, so they
                                    // would otherwise overlap what follows.
                                    .padding(bottom = (layers.lastOrNull()?.offset ?: 0f).dp),
                            ) {
                                // Blank cards, deliberately: they stand for
                                // courses the learner has, and a title drawn
                                // at 90% scale and half opacity would be a
                                // label nobody can read.
                                layers.reversed().forEach { layer ->
                                    Box(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(206.dp)
                                            .offset(y = layer.offset.dp)
                                            .graphicsLayer {
                                                scaleX = layer.scale
                                                transformOrigin = TransformOrigin(0.5f, 0f)
                                                alpha = layer.opacity
                                            }
                                            .clip(RoundedCornerShape(21.dp))
                                            .background(Color(0xFF1C2436))
                                            .border(1.dp, Color(0x1CFFFFFF), RoundedCornerShape(21.dp)),
                                    )
                                }

                                val openDeck: (() -> Unit)? =
                                    if (layers.isNotEmpty()) {
                                        ({ deckExpanded = true })
                                    } else {
                                        null
                                    }

                                StackDeckCard(
                                    item = visible.first(),
                                    nav = nav,
                                    onTapBody = openDeck,
                                )
                            }
                        }

                        // Shut, this says how many courses are waiting — the
                        // real number from the list, not the two cards drawn
                        // behind the top one.
                        FocusPresentation.deckMoreLabel(visible.size)?.let { more ->
                            Row(
                                horizontalArrangement = Arrangement.Center,
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(top = 12.dp)
                                    .clip(RoundedCornerShape(50))
                                    .background(Color(0x0DFFFFFF))
                                    .clickable { deckExpanded = !deckOpen }
                                    .padding(vertical = 10.dp),
                            ) {
                                Text(
                                    text = if (deckOpen) "Stack them back up" else more,
                                    style = MaterialTheme.typography.labelLarge,
                                    color = TextSecondary,
                                )
                                Icon(
                                    imageVector = if (deckOpen) {
                                        Icons.Filled.KeyboardArrowUp
                                    } else {
                                        Icons.Filled.KeyboardArrowDown
                                    },
                                    contentDescription = null,
                                    tint = TextSecondary,
                                    modifier = Modifier.size(18.dp),
                                )
                            }
                        }
                    }
                }
            } else {
                EmptyLearningCard(
                    onClick = { nav.navigate(Routes.COURSES) },
                )
            }
        }

        item {
            SectionHeader("Explore Courses")
            when {
                featuredCourses.isNotEmpty() -> {
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        itemsIndexed(featuredCourses) { index, course ->
                            CatalogCourseCard(
                                course = course,
                                gradient = CardGradients[index % CardGradients.size],
                                onClick = { nav.navigate(Routes.courseDetail(course.idStr)) },
                            )
                        }
                    }
                }
                catalogError != null -> GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(18.dp)) {
                        Text(
                            text = "Course catalog unavailable",
                            style = MaterialTheme.typography.titleMedium,
                            color = TextPrimary,
                        )
                        Text(
                            text = catalogError ?: "The course catalog could not be loaded.",
                            style = MaterialTheme.typography.bodySmall,
                            color = TextSecondary,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                }
                else -> GlassCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { nav.navigate(Routes.COURSES) },
                ) {
                    Column(modifier = Modifier.padding(18.dp)) {
                        Text(
                            text = "No published courses",
                            style = MaterialTheme.typography.titleMedium,
                            color = TextPrimary,
                        )
                        Text(
                            text = "Open Courses to check for newly published learning content.",
                            style = MaterialTheme.typography.bodySmall,
                            color = TextSecondary,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                }
            }
        }

        item {
            SectionHeader("Learning Actions")
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                QuickActionCard(
                    icon = Icons.Filled.MenuBook,
                    label = "Browse Courses",
                    tint = LyoPurple,
                    onClick = { nav.navigate(Routes.COURSES) },
                    modifier = Modifier.weight(1f),
                )
                QuickActionCard(
                    icon = Icons.Filled.SmartToy,
                    label = "Ask Lyo",
                    tint = LyoBlue,
                    onClick = { nav.navigate(Routes.CHAT) },
                    modifier = Modifier.weight(1f),
                )
            }
        }

        item { Spacer(Modifier.height(8.dp)) }
    }
}

private fun humanizeSkillId(value: String): String =
    value.replace("_", " ")
        .replace("-", " ")
        .split(" ")
        .filter { it.isNotBlank() }
        .joinToString(" ") { token ->
            token.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
        }

@Composable
private fun StatCard(
    emoji: String,
    value: String,
    label: String,
    accent: Color,
    modifier: Modifier = Modifier,
) {
    GlassCard(modifier = modifier) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 16.dp, horizontal = 8.dp),
        ) {
            Text(emoji, style = MaterialTheme.typography.headlineSmall)
            Text(
                text = value,
                style = MaterialTheme.typography.headlineMedium,
                color = accent,
                modifier = Modifier.padding(top = 6.dp),
            )
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                color = TextSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
    }
}

/**
 * A card in the "Your Stacks" row — a course the user has actually
 * started (has a real, backend-synced StackItemDto), with live progress
 * and a share affordance. Replaces the old single-slot RecentCourseCard
 * (device-local, at most one course) with a real multi-item, device- and
 * platform-agnostic list — see StackRepository's doc comment.
 */
/**
 * One card of the deck, with the navigation and sharing this screen wires up.
 *
 * Extracted so the top of the deck and the cards underneath it are literally
 * the same call: a deck whose top card quietly had different actions from the
 * rest would be a trap rather than a shortcut.
 */
@Composable
private fun StackDeckCard(
    item: StackItemDto,
    nav: NavHostController,
    onTapBody: (() -> Unit)? = null,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val courseId = item.contentId ?: item.id.toString()

    StackCourseCard(
        item = item,
        onTapBody = onTapBody,
        onResume = { nav.navigate(Routes.classroom(courseId)) },
        onShareExternally = {
            val shareUrl = StackRepository.courseShareUrl(courseId)
            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, "Check out \"${item.title}\" on Lyo! $shareUrl")
            }
            context.startActivity(Intent.createChooser(sendIntent, null))
        },
        onPostToCommunity = {
            val progressPercent = (item.progress.coerceIn(0f, 1f) * 100).toInt()
            scope.launch {
                val posted = StackRepository.postCourseToCommunity(
                    courseId,
                    item.title,
                    progressPercent,
                )
                val message = if (posted) {
                    "Posted \"${item.title}\" to Community"
                } else {
                    "Couldn't post right now — try again later"
                }
                Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
            }
        },
    )
}

/**
 * One saved course, as a card that turns over.
 *
 * The front carries the action deliberately: tapping the card body flips it,
 * but Resume is its own button on the front, so studying stays one tap. A
 * flip that stood between a learner and the thing they opened the app for
 * would be a worse screen with a nicer animation.
 *
 * The corner button flips it too. That matters when the body's tap is taken
 * over by [onTapBody] — the top card of a shut deck opens the deck instead
 * of turning over — because the description has to stay reachable either
 * way.
 *
 * What it will not do is draw a progress figure the stack does not have. The
 * branching lives in [FocusPresentation], which is unit-tested.
 */
@Composable
private fun StackCourseCard(
    item: StackItemDto,
    onResume: () -> Unit,
    onShareExternally: () -> Unit,
    onPostToCommunity: () -> Unit,
    /**
     * Takes over the card body's tap, for the top card of a shut deck.
     *
     * When the deck is shut, tapping the card sitting on top of it should
     * open the deck, not turn that one card over. Resume and the flip button
     * are untouched either way, so a shut deck never costs a learner a tap
     * on the way to studying.
     */
    onTapBody: (() -> Unit)? = null,
) {
    var flipped by remember(item.id) { mutableStateOf(false) }
    val rotation by animateFloatAsState(
        targetValue = if (flipped) 180f else 0f,
        animationSpec = tween(durationMillis = 480),
        label = "cardFlip",
    )
    val action = FocusPresentation.actionFor(item)
    val finished = FocusPresentation.isFinished(item)
    val progress = FocusPresentation.progressFor(item)

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(206.dp)
            .graphicsLayer {
                rotationY = rotation
                cameraDistance = 14f * density
            }
            .clip(RoundedCornerShape(21.dp))
            .clickable {
                if (onTapBody != null) onTapBody() else flipped = !flipped
            },
    ) {
        // Past the halfway point the back is facing the viewer, so the faces
        // swap there and neither is ever shown mirrored.
        if (rotation <= 90f) {
            CourseArtwork(title = item.title, modifier = Modifier.fillMaxSize())
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(
                                Color(0x0F05070D),
                                Color(0x8505070D),
                                Color(0xF005070D),
                            ),
                        ),
                    ),
            )

            if (finished) {
                Text(
                    text = "FINISHED",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFFBDF5DA),
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(14.dp)
                        .clip(RoundedCornerShape(7.dp))
                        .background(Color(0x3310B981))
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                )
            }

            Row(
                modifier = Modifier.align(Alignment.TopEnd),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                StackCardMenu(
                    onShareExternally = onShareExternally,
                    onPostToCommunity = onPostToCommunity,
                )
                FlipButton(flipped = false, onClick = { flipped = true })
            }

            Column(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(9.dp),
            ) {
                Text(
                    text = item.title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )

                when (progress) {
                    is FocusPresentation.Progress.Measured -> {
                        LinearProgressIndicator(
                            progress = { progress.percent / 100f },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(4.dp)
                                .clip(CircleShape),
                            color = if (finished) Color(0xFF3ED68E) else Color(0xFFB59CFF),
                            trackColor = Color.White.copy(alpha = 0.2f),
                        )
                        Text(
                            text = when {
                                finished -> "Complete"
                                item.status == "not_started" && progress.percent == 0 -> "Not started"
                                else -> "${progress.percent}%"
                            },
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.White.copy(alpha = 0.7f),
                        )
                    }
                    // No figure arrived. An empty bar would claim the learner
                    // is at the start of the course, which is a different
                    // thing from the app not knowing.
                    FocusPresentation.Progress.Unknown -> Text(
                        text = "Progress not recorded yet",
                        style = MaterialTheme.typography.labelSmall,
                        color = Color.White.copy(alpha = 0.55f),
                    )
                }

                Button(
                    onClick = onResume,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.White,
                        contentColor = Color(0xFF0A0D16),
                    ),
                    shape = CircleShape,
                    contentPadding = PaddingValues(horizontal = 18.dp, vertical = 8.dp),
                ) {
                    Text(action.label, fontWeight = FontWeight.Bold)
                }
            }
        } else {
            // Counter-rotated so the back reads the right way round.
            Box(modifier = Modifier.fillMaxSize().graphicsLayer { rotationY = 180f }) {
                CourseArtwork(
                    title = item.title,
                    modifier = Modifier.fillMaxSize().graphicsLayer { alpha = 0.16f },
                )
                Box(modifier = Modifier.fillMaxSize().background(Color(0xDB141A2A)))

                FlipButton(
                    flipped = true,
                    onClick = { flipped = false },
                    modifier = Modifier.align(Alignment.TopEnd).padding(4.dp),
                )

                Column(
                    modifier = Modifier.fillMaxSize().padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        text = "ABOUT THIS COURSE",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFFB59CFF),
                    )
                    when (val blurb = FocusPresentation.blurbFor(item)) {
                        is FocusPresentation.Blurb.Description -> Text(
                            text = blurb.text,
                            style = MaterialTheme.typography.bodySmall,
                            color = Color.White.copy(alpha = 0.78f),
                            maxLines = 5,
                            overflow = TextOverflow.Ellipsis,
                        )
                        is FocusPresentation.Blurb.Status -> {
                            Text(
                                text = "Where it stands",
                                style = MaterialTheme.typography.labelSmall,
                                color = Color.White.copy(alpha = 0.4f),
                            )
                            Text(
                                text = blurb.text,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = Color.White.copy(alpha = 0.84f),
                            )
                        }
                        FocusPresentation.Blurb.None -> Text(
                            text = "No description was saved with this course.",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color.White.copy(alpha = 0.5f),
                        )
                    }
                    Spacer(Modifier.weight(1f))
                    Button(
                        onClick = onResume,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Color.White.copy(alpha = 0.11f),
                            contentColor = Color.White,
                        ),
                        shape = CircleShape,
                        contentPadding = PaddingValues(horizontal = 18.dp, vertical = 8.dp),
                    ) {
                        Text(action.label, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}

/**
 * Turns a course card over.
 *
 * A real control, not decoration. The card body's own tap used to be the
 * only way to flip, which was fine until the top card of a shut deck gave
 * that tap up to opening the deck: without this button the description of
 * the course on top could not be reached without opening the deck first.
 * Web has always had it; iOS and Android were the odd ones out.
 */
@Composable
private fun FlipButton(
    flipped: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    IconButton(onClick = onClick, modifier = modifier) {
        Icon(
            imageVector = Icons.Filled.Refresh,
            contentDescription = if (flipped) "Show progress" else "Show description",
            tint = Color.White,
        )
    }
}

/**
 * Two distinct actions, both building on the same courseShareUrl
 * (StackRepository): "Share" hands off to any installed app via the OS share
 * sheet; "Post to Community" publishes inside Lyo's own Community feed — see
 * StackRepository.postCourseToCommunity's doc comment.
 */
@Composable
private fun StackCardMenu(
    onShareExternally: () -> Unit,
    onPostToCommunity: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var expanded by remember { mutableStateOf(false) }
    Box(modifier = modifier) {
        IconButton(onClick = { expanded = true }) {
            Icon(Icons.Filled.Share, contentDescription = "Share course", tint = Color.White)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            DropdownMenuItem(
                text = { Text("Share…") },
                leadingIcon = { Icon(Icons.Filled.Share, contentDescription = null) },
                onClick = {
                    expanded = false
                    onShareExternally()
                },
            )
            DropdownMenuItem(
                text = { Text("Post to Community") },
                leadingIcon = { Icon(Icons.Filled.People, contentDescription = null) },
                onClick = {
                    expanded = false
                    onPostToCommunity()
                },
            )
        }
    }
}

@Composable
private fun EmptyLearningCard(onClick: () -> Unit) {
    GlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp),
        ) {
            Text(
                text = "No courses in your Stacks yet",
                style = MaterialTheme.typography.titleMedium,
                color = TextPrimary,
            )
            Text(
                text = "Start a course from Explore and it'll show up here — and on any other device you sign into.",
                style = MaterialTheme.typography.bodySmall,
                color = TextSecondary,
                modifier = Modifier.padding(top = 5.dp),
            )
        }
    }
}

@Composable
private fun CatalogCourseCard(
    course: CourseDto,
    gradient: Brush,
    onClick: () -> Unit,
) {
    GlassCard(
        modifier = Modifier
            .width(200.dp)
            .clickable(onClick = onClick),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(72.dp)
                .clip(RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp))
                .background(gradient),
        )
        Column(modifier = Modifier.padding(12.dp)) {
            Text(
                text = course.title ?: "Untitled Course",
                style = MaterialTheme.typography.titleMedium,
                color = TextPrimary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = course.subject ?: "General",
                style = MaterialTheme.typography.labelMedium,
                color = TextSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}

@Composable
private fun QuickActionCard(
    icon: ImageVector,
    label: String,
    tint: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    GlassCard(modifier = modifier.clickable(onClick = onClick)) {
        Column(modifier = Modifier.padding(16.dp)) {
            Icon(icon, contentDescription = label, tint = tint, modifier = Modifier.size(24.dp))
            Text(
                text = label,
                style = MaterialTheme.typography.titleSmall,
                color = TextPrimary,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
    }
}
