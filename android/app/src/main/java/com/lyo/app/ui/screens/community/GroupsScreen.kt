package com.lyo.app.ui.screens.community

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.People
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.GroupDto
import com.lyo.app.ui.components.CardGradients
import com.lyo.app.ui.components.EmptyState
import com.lyo.app.ui.components.GlassCard
import com.lyo.app.ui.components.LoadingBox
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GroupsScreen(nav: NavHostController) {
    var groups by remember { mutableStateOf<List<GroupDto>>(emptyList()) }
    var joinedIds by remember { mutableStateOf(setOf<String>()) }
    var loading by remember { mutableStateOf(true) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        runCatching { ApiClient.api.groups() }
            .onSuccess { groups = it }
        loading = false
    }

    Scaffold(
        containerColor = Background,
        topBar = {
            TopAppBar(
                title = { Text("Study Groups") },
                navigationIcon = {
                    IconButton(onClick = { nav.popBackStack() }) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = TextPrimary,
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Background,
                    titleContentColor = TextPrimary,
                ),
            )
        },
    ) { padding ->
        when {
            loading -> LoadingBox(modifier = Modifier.padding(padding))
            groups.isEmpty() -> EmptyState(
                title = "No groups yet",
                subtitle = "Create or join groups to learn together",
                modifier = Modifier.padding(padding),
            )
            else -> LazyColumn(
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
            ) {
                itemsIndexed(groups) { index, group ->
                    val id = group.idStr
                    val joined = id in joinedIds
                    GlassCard(modifier = Modifier.fillMaxWidth()) {
                        // Gradient banner
                        Spacer(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(72.dp)
                                .background(CardGradients[index % CardGradients.size]),
                        )
                        Column(modifier = Modifier.padding(14.dp)) {
                            Text(
                                group.name ?: "Group",
                                style = MaterialTheme.typography.titleLarge,
                            )
                            if (!group.description.isNullOrBlank()) {
                                Spacer(Modifier.height(4.dp))
                                Text(
                                    group.description,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = TextSecondary,
                                    maxLines = 2,
                                    overflow = TextOverflow.Ellipsis,
                                )
                            }
                            Spacer(Modifier.height(10.dp))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    Icons.Filled.People,
                                    contentDescription = "Members",
                                    tint = TextSecondary,
                                    modifier = Modifier.size(16.dp),
                                )
                                Spacer(Modifier.width(6.dp))
                                Text(
                                    "${group.memberCount ?: 0} members",
                                    style = MaterialTheme.typography.labelLarge,
                                    color = TextSecondary,
                                )
                                Spacer(Modifier.weight(1f))
                                if (joined) {
                                    OutlinedButton(
                                        onClick = {
                                            joinedIds = joinedIds - id
                                            scope.launch {
                                                runCatching { ApiClient.api.leaveGroup(id) }
                                            }
                                        },
                                    ) {
                                        Text("Leave", color = TextSecondary)
                                    }
                                } else {
                                    Button(
                                        onClick = {
                                            joinedIds = joinedIds + id
                                            scope.launch {
                                                runCatching { ApiClient.api.joinGroup(id) }
                                            }
                                        },
                                        colors = ButtonDefaults.buttonColors(
                                            containerColor = LyoPurple,
                                            contentColor = Color.White,
                                        ),
                                    ) {
                                        Text("Join")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
