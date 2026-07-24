package com.lyo.app.ui.navigation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.lyo.app.data.RecentCourseStore
import com.lyo.app.data.Session
import com.lyo.app.ui.screens.auth.LoginScreen
import com.lyo.app.ui.screens.auth.SignupScreen
import com.lyo.app.ui.screens.chat.ChatScreen
import com.lyo.app.ui.screens.clips.ClipsScreen
import com.lyo.app.ui.screens.community.CommunityScreen
import com.lyo.app.ui.screens.community.GroupsScreen
import com.lyo.app.ui.screens.community.PostDetailScreen
import com.lyo.app.ui.screens.create.CreateClipScreen
import com.lyo.app.ui.screens.create.CreateCommunityItemScreen
import com.lyo.app.ui.screens.create.CreatePostScreen
import com.lyo.app.ui.screens.create.CreateScreen
import com.lyo.app.ui.screens.courses.CourseDetailScreen
import com.lyo.app.ui.screens.courses.CoursesScreen
import com.lyo.app.ui.screens.discover.DiscoverScreen
import com.lyo.app.ui.screens.home.HomeScreen
import com.lyo.app.ui.screens.messages.MessagesScreen
import com.lyo.app.ui.screens.notifications.NotificationsScreen
import com.lyo.app.ui.screens.profile.ProfileScreen
import com.lyo.app.ui.screens.settings.SettingsScreen
import com.lyo.app.ui.screens.stories.StoriesScreen
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.launch

object Routes {
    const val LOGIN = "login"
    const val SIGNUP = "signup"
    const val HOME = "home"
    const val CHAT = "chat"
    const val COMMUNITY = "community"
    const val POST_DETAIL = "community/{postId}"
    const val GROUPS = "groups"
    const val CLIPS = "clips"
    const val CREATE = "create"
    const val CREATE_CLIP = "create/clip"
    const val CREATE_POST = "create/post"
    const val CREATE_GROUP = "create/group"
    const val CREATE_EVENT = "create/event"
    const val STORIES = "stories"
    const val COURSES = "courses"
    const val COURSE_DETAIL = "courses/{courseId}"
    const val DISCOVER = "discover"
    const val PROFILE = "profile"
    const val USER_PROFILE = "profile/{userId}"
    const val MESSAGES = "messages"
    const val NOTIFICATIONS = "notifications"
    const val SETTINGS = "settings"

    fun postDetail(postId: String) = "community/$postId"
    fun courseDetail(courseId: String) = "courses/$courseId"
    fun userProfile(userId: String) = "profile/$userId"
}

private data class BottomItem(val route: String, val label: String, val icon: ImageVector)

/**
 * Mirrors the iOS product hierarchy: Focus, Clips, Create, Community, Profile.
 * Chat remains a contextual destination opened from Create and other learning surfaces.
 */
private val bottomItems = listOf(
    BottomItem(Routes.HOME, "Focus", Icons.Filled.Home),
    BottomItem(Routes.CLIPS, "Clips", Icons.Filled.PlayCircle),
    BottomItem(Routes.CREATE, "Create", Icons.Filled.Add),
    BottomItem(Routes.COMMUNITY, "Community", Icons.Filled.People),
    BottomItem(Routes.PROFILE, "Profile", Icons.Filled.Person),
)

@Composable
fun LyoApp() {
    when {
        Session.isLoading -> SessionLoadingScreen()
        Session.hydrationError != null -> SessionRecoveryScreen(
            message = Session.hydrationError
                ?: "LYO could not verify your saved session.",
        )
        else -> LyoNavHost()
    }
}

@Composable
private fun LyoNavHost() {
    val nav: NavHostController = rememberNavController()
    val backStack by nav.currentBackStackEntryAsState()
    val currentRoute = backStack?.destination?.route

    val showBottomBar = currentRoute in bottomItems.map { it.route }

    Scaffold(
        containerColor = Background,
        bottomBar = {
            if (showBottomBar) {
                NavigationBar(containerColor = Surface) {
                    bottomItems.forEach { item ->
                        NavigationBarItem(
                            selected = currentRoute == item.route,
                            onClick = {
                                if (currentRoute != item.route) {
                                    nav.navigate(item.route) {
                                        popUpTo(Routes.HOME) { saveState = true }
                                        launchSingleTop = true
                                        restoreState = true
                                    }
                                }
                            },
                            icon = { Icon(item.icon, contentDescription = item.label) },
                            label = { Text(item.label) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = LyoPurple,
                                selectedTextColor = LyoPurple,
                                unselectedIconColor = TextSecondary,
                                unselectedTextColor = TextSecondary,
                                indicatorColor = LyoPurple.copy(alpha = 0.15f),
                            ),
                        )
                    }
                }
            }
        },
    ) { padding ->
        NavHost(
            navController = nav,
            startDestination = if (Session.isAuthenticated) Routes.HOME else Routes.LOGIN,
            modifier = Modifier.padding(padding),
        ) {
            composable(Routes.LOGIN) { LoginScreen(nav) }
            composable(Routes.SIGNUP) { SignupScreen(nav) }
            composable(Routes.HOME) { HomeScreen(nav) }
            composable(Routes.CHAT) { ChatScreen(nav) }
            composable(Routes.COMMUNITY) { CommunityScreen(nav) }
            composable(Routes.POST_DETAIL) { entry ->
                PostDetailScreen(nav, entry.arguments?.getString("postId") ?: "")
            }
            composable(Routes.GROUPS) { GroupsScreen(nav) }
            composable(Routes.CLIPS) { ClipsScreen(nav) }
            composable(Routes.CREATE) { CreateScreen(nav) }
            composable(Routes.CREATE_CLIP) { CreateClipScreen(nav) }
            composable(Routes.CREATE_POST) { CreatePostScreen(nav) }
            composable(Routes.CREATE_GROUP) {
                CreateCommunityItemScreen(nav = nav, createGroup = true)
            }
            composable(Routes.CREATE_EVENT) {
                CreateCommunityItemScreen(nav = nav, createGroup = false)
            }
            composable(Routes.STORIES) { StoriesScreen(nav) }
            composable(Routes.COURSES) { CoursesScreen(nav) }
            composable(Routes.COURSE_DETAIL) { entry ->
                val courseId = entry.arguments?.getString("courseId") ?: ""
                val context = LocalContext.current
                LaunchedEffect(courseId) {
                    RecentCourseStore.save(context, courseId)
                }
                CourseDetailScreen(nav, courseId)
            }
            composable(Routes.DISCOVER) { DiscoverScreen(nav) }
            composable(Routes.PROFILE) { ProfileScreen(nav, userId = null) }
            composable(Routes.USER_PROFILE) { entry ->
                ProfileScreen(nav, userId = entry.arguments?.getString("userId"))
            }
            composable(Routes.MESSAGES) { MessagesScreen(nav) }
            composable(Routes.NOTIFICATIONS) { NotificationsScreen(nav) }
            composable(Routes.SETTINGS) { SettingsScreen(nav) }
        }
    }
}

@Composable
private fun SessionLoadingScreen() {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
    ) {
        CircularProgressIndicator(color = LyoPurple)
        Text(
            text = "Verifying your LYO session…",
            style = MaterialTheme.typography.bodyMedium,
            color = TextSecondary,
            modifier = Modifier.padding(top = 16.dp),
        )
    }
}

@Composable
private fun SessionRecoveryScreen(message: String) {
    val scope = rememberCoroutineScope()

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
    ) {
        Text(
            text = "Session verification failed",
            style = MaterialTheme.typography.headlineSmall,
            color = TextPrimary,
            textAlign = TextAlign.Center,
        )
        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            color = TextSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 8.dp),
        )
        Button(
            onClick = { scope.launch { Session.hydrate() } },
            modifier = Modifier.padding(top = 20.dp),
        ) {
            Text("Retry")
        }
        TextButton(onClick = { scope.launch { Session.logout() } }) {
            Text("Sign out")
        }
    }
}
